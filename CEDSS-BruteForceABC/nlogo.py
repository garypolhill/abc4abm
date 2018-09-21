#!/usr/bin/python
"""nlogo.py
This module contains classes for reading and working with a NetLogo file
"""
# Copyright (C) 2018  The James Hutton Institute & University of Edinburgh
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public Licence as published by
# the Free Software Foundation, either version 3 of the Licence, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public Licence for more details.
#
# You should have received a copy of the GNU General Public Licence
# along with this program.  If not, see <https://www.gnu.org/licences/>.
__version__ = "0.1"
__author__ = "Gary Polhill"

# Imports
import io
import sys
import xml.etree.ElementTree as xml

# Classes

class Widget:
    type = "<<UNDEF>>"
    def __init__(self, type, left, top, right, bottom, display, parameter,
                 output, info):
        self.type = type
        self.left = left
        self.top = top
        self.right = right
        self.bottom = bottom
        self.display = display
        self.isParameter = parameter
        self.isOutput = output
        self.isInfo = info

    @staticmethod
    def read(fp):
        typestr = fp.readline()
        widgets = []
        while(typestr[0:-1] != "@#$#@#$#@"):
            typestr = typestr.strip()

            if typestr == GraphicsWindow.type:
                widgets.append(GraphicsWindow.read(fp))
            elif typestr == Button.type:
                widgets.append(Button.read(fp))
            elif typestr == Plot.type:
                widgets.append(Plot.read(fp))
            elif typestr == TextBox.type:
                widgets.append(TextBox.read(fp))
            elif typestr == Switch.type:
                widgets.append(Switch.read(fp))
            elif typestr == Chooser.type:
                widgets.append(Chooser.read(fp))
            elif typestr == Slider.type:
                widgets.append(Slider.read(fp))
            elif typestr == Monitor.type:
                widgets.append(Monitor.read(fp))
            elif typestr == OutputArea.type:
                widgets.append(OutputArea.read(fp))
            elif typestr == InputBox.type:
                widgets.append(InputBox.read(fp))
            else:
                sys.stderr.write("Unrecognized widget type: %s\n"%(typestr))
                while(typestr.strip() != ""):
                    typestr = fp.readline

            typestr = fp.readline()
            if typestr.strip() == '':
                typestr = fp.readline()

        return widgets


class GraphicsWindow(Widget):
    type = "GRAPHICSWINDOW"
    def __init__(self, left, top, right, bottom, patch_size, font_size, x_wrap,
                 y_wrap, min_pxcor, max_pxcor, min_pycor, max_pycor, update_mode,
                 show_ticks, tick_label, frame_rate):
        Widget.__init__(self, GraphicsWindow.type, left, top, right, bottom, "")
        self.patchSize = patch_size
        self.fontSize = font_size
        self.xWrap = x_wrap
        self.yWrap = y_wrap
        self.minPXCor = min_pxcor
        self.maxPXCor = max_pxcor
        self.minPYCor = min_pycor
        self.maxPYCor = max_pycor
        self.updateMode = update_mode
        self.showTicks = show_ticks
        self.tickLabel = tick_label
        self.frameRate = frame_rate

    @staticmethod
    def read(fp):
        left = int(fp.readline())
        top = int(fp.readline())
        right = int(fp.readline())
        bottom = int(fp.readline())
        res1 = fp.readline()
        res2 = fp.readline()
        patch_size = float(fp.readline())
        res3 = fp.readline()
        font_size = int(fp.readline())
        res4 = fp.readline()
        res5 = fp.readline()
        res6 = fp.readline()
        res7 = fp.readline()
        x_wrap = fp.readline().strip() == "1"
        y_wrap = fp.readline().strip() == "1"
        res8 = fp.readline()
        min_pxcor = int(fp.readline())
        max_pxcor = int(fp.readline())
        min_pycor = int(fp.readline())
        max_pycor = int(fp.readline())
        update_mode = int(fp.readline())
        res9 = fp.readline()
        show_ticks = fp.readline().strip() == "1"
        tick_label = fp.readline().strip()
        frame_rate = float(fp.readline())

        return GraphicsWindow(left, top, right, bottom, patch_size, font_size,
                              x_wrap, y_wrap, min_pxcor, max_pxcor, min_pycor,
                              max_pycor, update_mode, show_ticks, tick_lable,
                              frame_rate)


class Button(Widget):
    type = "BUTTON"
    def __init__(self, left, top, right, bottom, display, code, forever,
                 button_type, action_key, always_enable):
        Widget.__init__(self, Button.type, left, top, right, bottom, display)
        self.code = code
        self.forever = forever
        self.buttonType = button_type
        self.actionKey = action_key
        self.alwaysEnable = always_enable

    @staticmethod
    def read(fp):
        left = int(fp.readline())
        top = int(fp.readline())
        right = int(fp.readline())
        bottom = int(fp.readline())
        display = fp.readline().strip()
        code = fp.readline().strip()
        forever = (fp.readline().strip() == "T")
        res1 = fp.readline()
        res2 = fp.readline()
        button_type = fp.readline().strip()
        res3 = fp.readline()
        action_key = fp.readline().strip()
        res4 = fp.readline()
        res5 = fp.readline()
        always_enable = (int(fp.readline()) == 1)

        return Button(left, top, right, bottom, display, code, forever,
                      button_type, action_key, always_enable)

class Parameter(Widget):
    def __init__(self, type, left, top, right, bottom, display):
        Widget.__init__(self, type, left, top, right, bottom, display, True, False, False)

class Output(Widget):
    def __init__(self, type, left, top, right, bottom, display):
        Widget.__init__(self, type, left, top, right, bottom, display, False, True, False)

class Info(Widget):
    def __init__(self, type, left, top, right, bottom, display):
        Widget.__init__(self, type, left, top, right, bottom, display, False, False, True)

class Plot(Output):
    type = "PLOT"
    def __init__(self, left, top, right, bottom, display, xaxis, yaxis, xmin,
                 xmax, ymin, ymax, autoplot_on, legend_on, code1, code2):
        Output.__init__(self, Plot.type, left, top, right, bottom, display)
        self.xaxis = xaxis
        self.yaxis = yaxis
        self.xmin = xmin
        self.ymin = ymin
        self.ymax = ymax
        self.autoplotOn = autoplot_on
        self.legendOn = legend_on
        self.code1 = code1
        self.code2 = code2
        self.pens = []

    @staticmethod
    def read(fp):
        left = int(fp.readline())
        top = int(fp.readline())
        right = int(fp.readline())
        bottom = int(fp.readline())
        display = fp.readline().strip()
        xaxis = fp.readline().strip()
        yaxis = fp.readline().strip()
        xmin = float(fp.readline())
        xmax = float(fp.readline())
        ymin = float(fp.readline())
        ymax = float(fp.readline())
        autoplot_on = (fp.readline().strip() == "true")
        legend_on = (fp.readline().strip() == "true")
        codes = (fp.readline().strip().split('" "'))

        plot = Plot(left, right, top, bottom, display, xaxis, yaxis,
                    xmin, xmax, ymax, autoplot_on, codes[0][1:-1], codes[1][0:-2])
        if(fp.readline().strip() == "PENS"):
            penstr = fp.readline().strip()
            while penstr != '':
                plot.addPen(Pen.parse(penstr))

        return plot

    def addPen(self, pen):
        self.pens[pen.display] = pen

class Pen:
    def __init__(self, display, interval, mode, colour, in_legend, setup_code,
                 update_code):
        self.display = display
        self.interval = interval
        self.mode = mode
        self.colour = colour
        self.inLegend = in_legend
        self.setupCode = setup_code
        self.updateCode = update_code

    @staticmethod
    def parse(penstr):


class TextBox(Info):
    type = "TEXTBOX"
    def __init__(self, left, top, right, bottom, display, font_size, colour,
                 transparent):
        Info.__init__(self, TextBox.type, left, top, right, bottom, display)
        self.fontSize = font_size
        self.colour = colour
        self.transparent = transparent

class Switch(Parameter):
    type = "SWITCH"
    def __init__(self, left, top, right, bottom, display, varname, on):
        Parameter.__init__(self, Switch.type, left, top, right, bottom, display)
        self.varname = varname
        self.isSwitchedOn = (on == 0)

class Chooser(Parameter):
    type = "CHOOSER"
    def __init__(self, left, top, right, bottom, display, varname, choices,
                 selection):
        Parameter.__init__(self, Chooser.type, left, top, right, bottom, display)
        self.varname = varname
        self.choices = choices
        self.selection = selection

class Slider(Parameter):
    type = "SLIDER"
    def __init__(self, left, top, right, bottom, display, varname, min, max,
                 default, step, units, orientation):
        Parameter.__init__(self, Slider.type, left, top, right, bottom, display)
        self.varname = varname
        self.minimum = min
        self.maximum = max
        self.default = default
        self.step = step
        self.units = units
        self.isHorizontal = (orientation == "HORIZONTAL")

class Monitor(Output):
    type = "MONITOR"
    def __init__(self, left, top, right, bottom, display, source, precision,
                 font_size):
        Output.__init__(self, Monitor.type, left, top, right, bottom, display)
        self.source = source
        self.precision = precision
        self.fontSize = font_size

class OutputArea(Output):
    type = "OUTPUT"
    def __init__(self, left, top, right, bottom, font_size):
        Output.__init__(self, OutputArea.type, left, top, right, bottom, "")

class InputBox(Parameter):
    type = "INPUTBOX"
    def __init__(self, left, top, right, bottom, varname, value, multiline,
                 datatype):
        Parameter.__init__(self, InputBox.type, left, top, right, bottom, "")
        self.varname = varname
        self.value = value
        self.isMultiline = multiline
        self.isNumeric = (datatype == "Number")
        self.isString = (datatype == "String")
        self.isCommand = (datatype == "String (command)")
        self.isReporter = (datatype == "String (reporter)")
        self.isColour = (datatype == "Color")

class BahaviorSpaceXMLError(Exception):
    def __init__(self, file, expected, found):
        self.file = file
        self.expected = exected
        self.found = found

    def __str__(self):
        return "BehaviorSpace XML format error in file %s: expected \"%s\", found \"%s\""%(self.file, self.expected, self.found)

class SteppedValue:
    def __init__(self, variable, first, step, last):
        self.variable = variable
        self.first = first
        self.step = step
        self.last = last

    @staticmethod
    def fromXML(xml, file_name):
        if xml.tag != "steppedValueSet":
            raise BehaviorSpaceXMLError(file_name, "steppedValueSet", xml.tag)
        return SteppedValue(xml.get("variable"), xml.get("first"),
                            xml.get("step"), xml.get("last"))

class EnumeratedValue:
    def __init__(self, variable, values):
        self.variable = variable
        self.values = values

    @staticmethod
    def fromXML(xml, file_name):
        if xml.tag != "enumeratedValueSet":
            raise BehaviorSpaceXMLError(file_name, "enumeratedValueSet", xml.tag)

        variable = xml.get("variable")
        values = []
        for value in xml:
            if value.tag != "value":
                raise BehaviorSpaceXMLError(file_name, "value", value.tag)
            values.append(value.get("value"))

        return EnumeratedValue(variable, values)

class Experiment:
    def __init__(self, name, setup, go, final, time_limit, exit_condition,
                 metrics, stepped_values = [], enumerated_values = [],
                 repetitions = 1, sequential_run_order = True,
                 run_metrics_every_step = True):
        self.name = name
        self.setup = setup
        self.go = go
        self.final = final
        self.timeLimit = time_limit
        self.exitCondition = exit_condition
        self.metrics = metrics
        self.steppedValueSet = stepped_values
        self.enumeratedValueSet = enumerated_values
        self.repetitions = repetitions
        self.sequentialRunOrder = sequential_run_order
        self.runMetricsEveryStep = run_metrics_every_step

    @staticmethod
    def fromXMLString(str, file_name):
        experiments = []
        if str == None or str.strip() == "":
            return []
        xml = xml.XML(str)
        if xml.tag != "experiments":
            raise BehaviorSpaceXMLError(file_name, "experiments", xml.tag)
        for exp in xml:
            if exp.tag != "experiment":
                raise BehaviorSpaceXMLError(file_name, "experiment", exp.tag)
            repetitions = 1
            sequential_run_order = True
            run_metrics_every_step = True
            name = None
            for attr in exp.keys():
                if attr == "name":
                    name = exp.get(attr)
                elif attr == "repetitions":
                    repetitions = exp.get(attr)
                elif attr == "sequentialRunOrder":
                    sequential_run_order = (exp.get(attr) == "true")
                elif attr == "runMetricsEveryStep":
                    run_metrics_every_step = (exp.get(attr) == "true")
                else:
                    raise BehaviorSpaceXMLError(file_name,
                        "name|repetitions|sequentialRunOrder|runMetricsEveryStep",
                        attr)
            if name == None:
                raise BehaviorSpaceXMLError(file_name, "name",
                                            "no \"name\" attribute for experiment")
            setup = ""
            go = ""
            final = ""
            time_limit = None
            exit_condition = None
            metrics = []
            stepped_values = []
            enumerated_values = []

            for elem in exp:
                if elem.tag == "setup":
                    setup = elem.text
                elif elem.tag == "go":
                    go = elem.text
                elif elem.tag == "final":
                    final = elem.text
                elif elem.tag == "timeLimit":
                    time_limit = float(elem.get("steps"))
                    if time_limit == None:
                        raise BehaviorSpaceXML(file_name, "steps",
                                               "no \"steps\" attribute for timeLimit")
                elif elem.tag == "exitCondition":
                    exit_condition = elem.text
                elif elem.tag == "metric":
                    metrics.append(elem.text)
                elif elem.tag == "steppedValueSet":
                    stepped_values.append(SteppedValue.fromXML(elem, file_name))
                elif elem.tag == "enumeratedValueSet":
                    enumerated_values.append(EnumeratedValue.fromXML(elem, file_name))
                else:
                    raise BehaviorSpaceXML(file_name, "experiment sub-element", elem.tag)

            experiments.append(Experiment, name, setup, go, final, time_limit,
                               exit_condition, metrics, stepped_values,
                               enumerated_values, repetitions,
                               sequential_run_order, run_metrics_every_step)
        return experiments

class NetlogoModel:
    def __init__(self, code, widgets, info, shapes, version, preview, sd,
                 behav, hubnet, link_shapes, settings, deltatick):
        self.code = code
        self.widgets = widgets
        self.info = info
        self.shapes = shapes
        self.version = version
        self.preview = preview
        self.sd = sd
        self.behav = behav
        self.hubnet = hubnet
        self.linkShapes = link_shapes
        self.settings = settings
        self.deltatick = deltatick

    @staticmethod
    def readSection(fp):
        section = ""
        for line in fp:
            if line[0:-1] == "@#$#@#$#@":
                break
            section = section + line
        return section

    @staticmethod
    def read(file_name):
        try:
            fp = io.open(file_name)
        except IOError as e:
            sys.stderr.write("Error opening file %s: %s\n"%(file_name, e.strerror))
            return False

        code = readSection(fp)

        widgets = Widgets.read(fp)

        info = readSection(fp)

        shapes = readSection(fp)

        version = readSection(fp)
        version = version[0:-1]

        preview = readSection(fp)

        sd = readSection(fp)

        behav = Experiment.fromXMLString(readSection(fp))

        hubnet = readSection(fp)

        link_shapes = readSection(fp)

        settings = readSection(fp)

        deltatick = readSection(fp)

        return NetlogoModel(code, widgets, info, shapes, version, preview,
                            sd, behav, hubet, link_shapes, settings, deltatick)
