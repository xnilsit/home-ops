#!/usr/bin/env python3
# Generates ./solar-dashboard.json: python3 solar-dashboard.py > solar-dashboard.json
import json

DS = {"type": "prometheus", "uid": "b25e598e-a1d1-4092-832c-2da8afcc42e1"}
LOGGERS = [("solar", "Logger 1"), ("solar2", "Logger 2")]
BOTH = "solar2?"
PRICE_EUR_PER_KWH = 0.35
ONLINE = "last_over_time({p}_logger_online[2m]) == 1"

POWER_STEPS = [{"color": "green"}, {"color": "orange", "value": 700}, {"color": "red", "value": 780}]
MODULE_STEPS = [{"color": "green"}, {"color": "orange", "value": 350}, {"color": "red", "value": 390}]
EFFICIENCY_STEPS = [{"color": "red"}, {"color": "orange", "value": 65}, {"color": "green", "value": 85}]
TEMP_STEPS = [{"color": "green"}, {"color": "orange", "value": 50}, {"color": "red", "value": 60}]
GREEN = [{"color": "green"}]
LAST = {"calcs": ["lastNotNull"], "fields": "", "values": False}


def q(ref, expr, legend, instant=True):
    return {"refId": ref, "datasource": DS, "expr": expr, "legendFormat": legend,
            "instant": instant, "range": not instant}


def per_logger(expr, instant=True):
    return [q(chr(65 + i), expr.format(p=p), name, instant) for i, (p, name) in enumerate(LOGGERS)]


def gated(expr):
    return f"{expr} and on() ({ONLINE})"


def panel(kind, title, pos, targets, defaults, options, **extra):
    x, y, w, h = pos
    return {"type": kind, "title": title, "datasource": DS, "gridPos": {"x": x, "y": y, "w": w, "h": h},
            "targets": targets, "fieldConfig": {"defaults": defaults, "overrides": extra.pop("overrides", [])},
            "options": options, **extra}


def gauge(title, pos, targets, unit, lo, hi, steps, no_value, steps_mode="absolute", **extra):
    return panel("gauge", title, pos, targets,
                 {"unit": unit, "min": lo, "max": hi, "noValue": no_value,
                  "thresholds": {"mode": steps_mode, "steps": steps}},
                 {"reduceOptions": LAST, "orientation": "auto",
                  "showThresholdLabels": False, "showThresholdMarkers": True}, **extra)


def bargauge(title, pos, targets):
    return panel("bargauge", title, pos, targets,
                 {"unit": "kwatth", "min": 0, "noValue": "All loggers offline",
                  "color": {"mode": "continuous-GrYlRd"}, "thresholds": {"mode": "absolute", "steps": GREEN}},
                 {"reduceOptions": LAST, "orientation": "horizontal", "displayMode": "lcd",
                  "showUnfilled": True, "valueMode": "color"})


def total(ref, metric, legend, window=None, instant=True):
    selector = f'{{__name__=~"{BOTH}_{metric}"}}'
    return q(ref, f"sum(last_over_time({selector}[{window}]))" if window else f"sum({selector})", legend, instant)


def modules(metric, window):
    return [total("total", metric, "Total", window)] + [
        q(f"{p}{ref}", f"last_over_time({p}{part}_{metric}[{window}])", name + label)
            for p, name in LOGGERS
            for ref, part, label in [("", "", ""), ("_m1", "_pv1", " module 1"), ("_m2", "_pv2", " module 2")]]


panels = [
    panel("stat", "Logger status", (0, 0, 3, 8),
          per_logger("last_over_time({p}_logger_online[2m]) or on() vector(0)"),
          {"color": {"mode": "thresholds"},
           "thresholds": {"mode": "absolute", "steps": [{"color": "red"}, {"color": "green", "value": 1}]},
           "mappings": [{"type": "value", "options": {"0": {"text": "Offline", "color": "red", "index": 0},
                                                      "1": {"text": "Online", "color": "green", "index": 1}}}]},
          {"reduceOptions": LAST, "orientation": "horizontal", "colorMode": "background",
           "graphMode": "none", "textMode": "value_and_name"}),
    gauge("AC power", (3, 0, 5, 8),
          per_logger(gated("sum({p}_l1_power)")) + [total("T", "l1_power", "Total")],
          "watt", 0, 800, POWER_STEPS, "Offline",
          overrides=[{"matcher": {"id": "byFrameRefID", "options": "T"}, "properties": [
              {"id": "max", "value": 1600},
              {"id": "thresholds", "value": {"mode": "absolute", "steps": [
                  {"color": "green"}, {"color": "orange", "value": 1400}, {"color": "red", "value": 1560}]}}]}]),
    gauge("DC power", (8, 0, 4, 8), per_logger(gated("sum({p}_dc_total_power)")),
          "watt", 0, 800, POWER_STEPS, "Offline"),
    *[gauge(f"Efficiency {name}", (12 + 2 * i, 0, 2, 8),
            [q("A", gated(f"100 * sum({p}_l1_power) / sum({p}_dc_total_power > 0)").format(p=p), name)],
            "percent", 0, 100, EFFICIENCY_STEPS, "Offline", steps_mode="percentage",
            description="AC output over DC input, from the latest reading.")
      for i, (p, name) in enumerate(LOGGERS)],
    panel("stat", "Both loggers", (16, 0, 8, 8),
          [q("POWER", f'sum({{__name__=~"{BOTH}_l1_power"}}) or on() vector(0)', "Power now"),
           total("TODAY", "day_energy", "Energy today", "12h"),
           # Last known lifetime totals, so an offline logger still counts.
           total("TOTAL", "total_energy", "Energy total", "1y"),
           # Public shares do not resolve dashboard variables, so the price is inlined.
           {"refId": "SAVED", "datasource": {"type": "__expr__", "uid": "__expr__"}, "type": "math",
            "expression": f"$TOTAL * {PRICE_EUR_PER_KWH}"}],
          {"min": 0, "color": {"mode": "fixed", "fixedColor": "green"},
           "thresholds": {"mode": "absolute", "steps": GREEN}},
          {"reduceOptions": LAST, "orientation": "vertical", "colorMode": "value",
           "graphMode": "none", "textMode": "value_and_name"},
          overrides=[{"matcher": {"id": "byFrameRefID", "options": ref},
                      "properties": [{"id": "unit", "value": unit}]}
                     for ref, unit in [("POWER", "watt"), ("TODAY", "kwatth"),
                                       ("TOTAL", "kwatth"), ("SAVED", "currencyEUR")]]),

    panel("timeseries", "Power history", (0, 8, 12, 8),
          [total("total_dc", "dc_total_power", "Total DC", instant=False),
           total("total_ac", "l1_power", "Total AC", instant=False)] +
          [q(f"{p}_{ref}", f"{p}_{metric}", f"{name} {label}", instant=False)
           for p, name in LOGGERS
           for ref, metric, label in [("dc", "dc_total_power", "DC"), ("ac", "l1_power", "AC"),
                                      ("m1", "pv1_power", "module 1"), ("m2", "pv2_power", "module 2")]],
          {"unit": "watt", "color": {"mode": "palette-classic"},
           "custom": {"drawStyle": "line", "lineInterpolation": "smooth", "lineWidth": 1,
                      "fillOpacity": 0, "showPoints": "auto", "spanNulls": False}},
          {"legend": {"displayMode": "list", "placement": "bottom", "showLegend": True},
           "tooltip": {"mode": "single", "sort": "none"}}),
    gauge("Module DC power", (12, 8, 8, 8),
          [q(f"{p}_m{m}", f"{p}_pv{m}_power", f"{name} module {m}") for p, name in LOGGERS for m in (1, 2)],
          "watt", 0, 400, MODULE_STEPS, "0"),
    gauge("Temperature", (20, 8, 4, 8), per_logger("sum({p}_radiator_temp)"),
          "celsius", -20, 65, TEMP_STEPS, "All loggers offline"),

    bargauge("Energy today", (0, 16, 12, 11), modules("day_energy", "12h")),
    bargauge("Energy total", (12, 16, 12, 11), modules("total_energy", "1y")),

    # offset -1d labels each bar with the day it covers rather than the next midnight.
    panel("timeseries", "Daily yield", (0, 27, 12, 9),
          per_logger("max_over_time({p}_day_energy[1d] offset -1d)", instant=False),
          {"unit": "kwatth", "min": 0, "color": {"mode": "palette-classic"},
           "custom": {"drawStyle": "bars", "fillOpacity": 80, "lineWidth": 1, "showPoints": "never",
                      "stacking": {"mode": "normal", "group": "A"}, "spanNulls": False}},
          {"legend": {"displayMode": "list", "placement": "bottom", "showLegend": True},
           "tooltip": {"mode": "multi", "sort": "none"}},
          timeFrom="30d", interval="1d", maxDataPoints=400),
    panel("barchart", "Monthly yield", (12, 27, 8, 9),
          [q("A", f'sum(max_over_time({{__name__=~"{BOTH}_day_energy"}}[1d] offset -1d))', "Energy",
             instant=False)],
          {"unit": "kwatth", "min": 0, "color": {"mode": "fixed", "fixedColor": "green"},
           "custom": {"fillOpacity": 80, "lineWidth": 1}},
          {"xField": "Time", "orientation": "auto", "showValue": "auto", "stacking": "none",
           "barWidth": 0.8, "groupWidth": 0.7, "xTickLabelRotation": 0,
           "legend": {"displayMode": "list", "placement": "bottom", "showLegend": False},
           "tooltip": {"mode": "single", "sort": "none"}},
          timeFrom="1y", interval="1d", maxDataPoints=400,
          transformations=[
              {"id": "convertFieldType", "options": {"conversions": [
                  {"targetField": "Time", "destinationType": "string", "dateFormat": "YYYY-MM"}]}},
              {"id": "groupBy", "options": {"fields": {
                  "Time": {"operation": "groupby", "aggregations": []},
                  "Energy": {"operation": "aggregate", "aggregations": ["sum"]}}}}]),
    panel("stat", "Best day, last 365 days", (20, 27, 4, 9), per_logger("max_over_time({p}_day_energy[1y])"),
          {"unit": "kwatth", "color": {"mode": "continuous-GrYlRd"},
           "thresholds": {"mode": "absolute", "steps": GREEN}},
          {"reduceOptions": {**LAST, "calcs": ["max"]}, "orientation": "vertical",
           "colorMode": "value", "graphMode": "none", "textMode": "auto"}),
]

for i, p in enumerate(panels, 1):
    p["id"] = i

print(json.dumps({
    "uid": "cc189c3b-7b6a-445b-9c26-40c68ee311b8",
    "title": "Solar Dashboard",
    "editable": True,
    "refresh": "30s",
    "time": {"from": "now-6h", "to": "now"},
    "timezone": "",
    "schemaVersion": 41,
    "templating": {"list": []},
    "annotations": {"list": []},
    "panels": panels,
}, indent=2, ensure_ascii=False))
