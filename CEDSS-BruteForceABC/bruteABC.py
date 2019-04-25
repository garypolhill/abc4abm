#!/usr/bin/python
"""bruteABC.py

This module contains code to analyse evidences for various models using
Approximate Bayesian Computation (ABC) and more than one metric. It uses a
'brute force' approach in that it relies on large numbers of runs of each
model to build a picture of the evidence profile. The number of runs needed
for a smooth evidence profile depends on the shape of the posterior. The
peakier and thinner the posterior, the more runs are needed -- possibly
millions.

When run as a script, it expects the following inputs:

1. A data file in CSV format with column headings:

   One column for each parameter or model setting varied
   One column for each metric

   One row for each run of the model with entries for parameters and metrics

2. A metric metadata file in CSV format with column headings:

   The first line should be 'metric,display,target,minimum,maximum,operator'

   One row for each metric. The metric name should match exactly one column
   heading in the data file. The target is the target value for the metric
   -- i.e. the value it would have if the model perfectly fitted the data.
   The minimum is the minimum 'reasonable' value; the maximum is the maximum
   'reasonable' value. The minimum and maximum are used to scale each metric
   so that the multiple metrics are comparable with each other. The operator
   column should be equal to "log" if logarithms of the metric should be taken.

3. A parameter metadata file in CSV format with column headings:

   The first line should be 'parameter,display,type,setting,minimum,maximum'

   One row for each parameter. The parameter name should match exactly one
   column heading in the data file. Minimum and maximum are needed for
   checking which parameters actually change. Type is needed for determining
   numeric parameters. Setting is ignored.

Outputs:

1. A CSV file with one column for epsilon values, and one column for each
   metric and combination thereof, and one column for each model version,
   with rows showing the evidence ratios for each model version and epsilon
   and metric/metric combination.

Authors: Jonathan Gair (University of Edinburgh)
         and Gary Polhill (The James Hutton Institute)
Date: 20 April 2019
Uses: numpy, scipy, pandas
Licence: GNU General Public Licence v3 (see comments)
"""
# Copyright (C) 2018-2019  The James Hutton Institute & University of Edinburgh
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
__version__ = "1.0"
__author__ = "Gary Polhill & Jonathan Gair"
# Imports: There are quite a lot of these, and many are only needed for
# visualization, which should be handled by a separate module. Minimum
# imports needed are sys, numpy and pandas. We may need scipy/optimize too,
# depending on how the epsilon scaling issue is resolved.
import sys
import os.path
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import corner as triangle
from scipy import optimize as op
from collections import Counter

# Globals that are local to this file

_DEFAULT_EPSTEPS = 100
_DEFAULT_MAXEP = 1.0
_DEFAULT_REFEPS = 0.05
_DEFAULT_LEGEND_POS = 'upper right'
_DEFAULT_EP_LABEL = r'$\epsilon_i$'
_DEFAULT_EVIDENCE_LABEL = r'${\cal Z}$'
_DEFAULT_FONT_SIZE = 'small'
_LOGRES_LOWER_BOUND = 0
_LOGRES_UPPER_BOUND = 10
_DEFAULT_LINE_COLOURS = [
                         '#1f78b4', # first
                         '#33a02c', # second
                         '#e31a1c', # third
                         '#ff7f00', # fourth
                         '#6a3d9a', # fifth
                         '#ffff99', # sixth
                         '#a6cee3', # seventh
                         '#b2df8a', # eighth
                         '#fb9a99', # ninth
                         '#fdbf6f', # tenth
                         '#cab2d6', # eleventh
                         '#b15928', # twelfth
                         ]  # From colour brewer
_DEFAULT_LINE_STYLE = '-'

class BruteABC:
    """BruceABC class

    Compute the evidence ratio given some data, and provide various utilities
    for saving and plotting the data.
    """
    def __init__(self, df, params, metrics, epsteps = _DEFAULT_EPSTEPS,
                 maxep = _DEFAULT_MAXEP, refeps = _DEFAULT_REFEPS, rescale = False):
        self.df = df
        n_dyn_parm = 0
        for i in range(len(params)):
            if (params['minimum'][i] != params['maximum'][i]) \
                and params['type'][i] == 'numeric':
                n_dyn_parm = n_dyn_parm + 1
        self.params = ["NA" for i in range(n_dyn_parm)]
        self.disp_params = ["NA" for i in range(n_dyn_parm)]

        j = 0
        for i in range(len(params)):
            if params['minimum'][i] != params['maximum'][i] \
                and params['type'][i] == 'numeric':
                self.params[j] = params['parameter'][i]
                self.disp_params[j] = params['display'][i]
                j = j + 1

        self.n_metrics = len(metrics)
        self.headers = [metrics['metric'][i] for i in range(self.n_metrics)]
        self.disp_metrics = [metrics['display'][i] for i in range(self.n_metrics)]
        self.calibvals = [metrics['target'][i] for i in range(self.n_metrics)]
        self.minima = [metrics['minimum'][i] for i in range(self.n_metrics)]
        self.maxima = [metrics['maximum'][i] for i in range(self.n_metrics)]

        self.rescale = rescale
        self.targets = pd.DataFrame(df.loc[:, self.headers])
        self.difima = [self.maxima[i] - self.minima[i] for i in range(self.n_metrics)]

        for i in range(self.n_metrics):
            if metrics['operator'][i] == "log":
                self.calibvals[i] = np.log(self.calibvals[i])
                self.minima[i] = np.log(self.minima[i])
                self.maxima[i] = np.log(self.maxima[i])
                self.difima[i] = self.maxima[i] - self.minima[i]
                self.df.loc[:, self.headers[i]] = np.log(self.df[self.headers[i]].to_numpy())
            for k in range(len(df.index)):
                self.targets.iloc[k, i] \
                    = (self.targets.iloc[k, i] - self.calibvals[i]) / self.difima[i]
            if self.minima[i] > self.calibvals[i]:
                sys.stderr.write("Metric %d (%s): minimum (%g) > calibration "
                                 "value (%g)\n"%(i, self.headers[i],
                                 self.minima[i], self.calibvals[i]))
                sys.exit(1)
            if self.calibvals[i] > self.maxima[i]:
                sys.stderr.write("Metric %d (%s): calibration value (%g) > "
                                 "maximum (%g)\n"%(i, self.headers[i],
                                 self.calibvals[i], self.maxima[i]))
                sys.exit(1)
            if self.minima[i] > self.maxima[i]:
                sys.stderr.write("Metric %d (%s): minimum (%g) > "
                                 "maximum (%g)\n"%(i, self.headers[i],
                                 self.minima[i], self.maxima[i]))
                sys.exit(1)

        self.epsteps = epsteps
        self.epsilons = [1.0 * (maxep / epsteps) * i for i in range(epsteps + 1)]
        self.refeps = refeps
        self.evidences = np.zeros(self.n_metrics * (epsteps + 1))
        self.evidences = self.evidences.reshape(self.n_metrics, epsteps + 1)
        self.evratio = np.zeros(self.n_metrics * (epsteps + 1))
        self.evratio = self.evratio.reshape(self.n_metrics, epsteps + 1)
        self.logevidences = np.zeros(self.n_metrics * (epsteps + 1))
        self.logevidences = self.logevidences.reshape(self.n_metrics, epsteps + 1)
        self.moments = 1.0 * np.zeros_like(self.calibvals)
        self.logmoments = 1.0 * np.zeros_like(self.calibvals)
        self.initscales = 1.0 * np.ones_like(self.calibvals)
        self.optscales = 1.0 * np.ones_like(self.calibvals)
        self.logoptscales = 1.0 * np.ones_like(self.calibvals)
        self.scales_computed = False

        for i in range(epsteps + 1):
            for j in range(self.n_metrics):
                self.evidences[j][i] \
                    = sum(1.0 for val in 1.0 * np.array(self.df[self.headers[j]])
                          if self.inEpsilonBox(val, self.epsilons[i], j)
                          ) / (1.0 * len(self.df[self.headers[j]]))
                if i > 0:
                    self.evratio[j][i] = self.evidences[j][i] / self.epsilons[i]
                self.moments[j] = self.moments[j] + self.evidences[j][i] * self.epsilons[i]
                if self.evidences[j][i] > 0.0:
                    self.logevidences[j][i] = np.log(self.evidences[j][i])
                    self.logmoments[j] \
                        = self.logmoments[j] + self.logevidences[j][i] * self.epsilons[i]

    def inEpsilonBox(self, value, epsilon, metric):
        """
        Return whether a value is within an epsilon of a metric
        """
        return (np.fabs((value - self.calibvals[metric]) / self.difima[metric])
                < epsilon)

    def saveEvidences(self, file_name, delimiter = ","):
        """
        Save the evidences to the file (CSV format by default)
        """
        outdata = np.array(np.reshape(self.epsilons, (self.epsteps + 1, 1)))
        for j in range(self.n_metrics):
            outdata = np.append(outdata,
                                np.reshape(self.evidences[j], (self.epsteps + 1, 1)),
                                axis = 1)
        np.savetxt(self.mkname(file_name), outdata, delimiter = delimiter,
                   header = "epsilon," + ",".join(self.headers))

    def saveEvidenceRatios(self, file_name, delimiter = ","):
        """
        Save the evidence ratio to the file (CSV format by default)
        """
        outdata = np.array(np.reshape(self.epsilons, (self.epsteps + 1, 1)))
        for j in range(self.n_metrics):
            outdata = np.append(outdata,
                                np.reshape(self.evratio[j], (self.epsteps + 1, 1)),
                                axis = 1)
        np.savetxt(self.mkname(file_name), outdata, delimiter = delimiter,
                   header = "epsilon," + ",".join(self.headers))

    def getEvidences(self, j, log = False, ratio = False):
        if ratio:
            if log:
                return(np.log(self.evratio[j]))
            else:
                return(self.evratio[j])
        else:
            if log:
                return(self.logevidences[j])
            else:
                return(self.evidences[j])

    def getEpsilons(self, j = 0, scaled = False, log = False):
        if scaled:
            self.computeScales()
            if log:
                return(np.array(self.epsilons) / self.logoptscales[j])
            else:
                return(np.array(self.epsilons) / self.optscales[j])
        else:
            return(np.array(self.epsilons))

    def plotEvidences(self, image_file, scaled = True, log = False, ratio = True,
                      line_colours = [],
                      line_styles = [],
                      legend_pos = _DEFAULT_LEGEND_POS,
                      x_label = _DEFAULT_EP_LABEL,
                      y_label = _DEFAULT_EVIDENCE_LABEL,
                      font_size = _DEFAULT_FONT_SIZE):
        """
        Plot the evidences, saving the graph to the image_file. Various options
        are provided to (a) scale the epsilon axis (or not); (b) plot
        log evidences rather than raw evidences; (c) plot evidences ratios
        rather than evidences. Convenience methods are provided to implement
        these options directly.
        """
        if line_colours == []:
            line_colours = _DEFAULT_LINE_COLOURS
        if line_styles == []:
            line_styles = [_DEFAULT_LINE_STYLE for i in range(self.n_metrics)]

        if scaled:
            self.computeScales()

        for j in range(self.n_metrics):
            xdata = self.getEpsilons(j, scaled, log)
            # if scaled:
            #     if log:
            #         xdata = np.array(self.epsilons) / self.logoptscales[j]
            #     else:       # not log
            #         xdata = np.array(self.epsilons) / self.optscales[j]
            # else:           # not scaled
            #     xdata = np.array(self.epsilons)

            data = self.getEvidences(j, log, ratio)
            # if ratio:
            #     if log:
            #         data = np.log(self.evratio[j])
            #     else:       # not log
            #         data = self.evratio[j]
            # else:           # not ratio
            #     if log:
            #         data = self.logevidences[j]
            #     else:       # not log
            #         data = self.evidences[j]

            plt.plot(xdata, (data), linewidth = 2,
                     linestyle = line_styles[j], color = line_colours[j],
                     label = 'Metric %i (%s)'%(j + 1, self.disp_metrics[j]))
        plt.xlabel(x_label)
        plt.ylabel(y_label)
        legend = plt.legend(loc = legend_pos, shadow = False, frameon = False,
                            fontsize = font_size) #, markerfirst = False)
        if not log:
            plt.plot([0, 1], [1, 1], linestyle = 'dashed', color = '#000000')
        plt.xlim([0, 1])
        plt.savefig(self.mkname(image_file))
        plt.close()

    def plotEvidence(self, png_file,
                     line_colours = [],
                     line_styles = [],
                     legend_pos = _DEFAULT_LEGEND_POS,
                     x_label = _DEFAULT_EP_LABEL,
                     y_label = _DEFAULT_EVIDENCE_LABEL):
        self.plotEvidences(png_file, False, False, False,
                           line_colours, line_styles, legend_pos, x_label,
                           y_label)

    def plotEvidenceRatio(self, png_file,
                          line_colours = [],
                          line_styles = [],
                          legend_pos = _DEFAULT_LEGEND_POS,
                          x_label = _DEFAULT_EP_LABEL,
                          y_label = _DEFAULT_EVIDENCE_LABEL):
        self.plotEvidences(png_file, False, False, True,
                           line_colours, line_styles, legend_pos, x_label,
                           y_label)

    def plotLogEvidence(self, png_file,
                        line_colours = [],
                        line_styles = [],
                        legend_pos = _DEFAULT_LEGEND_POS,
                        x_label = _DEFAULT_EP_LABEL,
                        y_label = _DEFAULT_EVIDENCE_LABEL):
        self.plotEvidences(png_file, False, True, False,
                           line_colours, line_styles, legend_pos, x_label,
                           y_label)

    def plotLogEvidenceRatio(self, png_file,
                             line_colours = [],
                             line_styles = [],
                             legend_pos = _DEFAULT_LEGEND_POS,
                             x_label = _DEFAULT_EP_LABEL,
                             y_label = _DEFAULT_EVIDENCE_LABEL):
        self.plotEvidences(png_file, False, True, True,
                           line_colours, line_styles, legend_pos, x_label,
                           y_label)

    def plotScaledEvidence(self, png_file,
                           line_colours = [],
                           line_styles = [],
                           legend_pos = _DEFAULT_LEGEND_POS,
                           x_label = _DEFAULT_EP_LABEL,
                           y_label = _DEFAULT_EVIDENCE_LABEL):
        self.plotEvidences(png_file, True, False, False,
                           line_colours, line_styles, legend_pos, x_label,
                           y_label)

    def plotScaledEvidenceRatio(self, png_file,
                                line_colours = [],
                                line_styles = [],
                                legend_pos = _DEFAULT_LEGEND_POS,
                                x_label = _DEFAULT_EP_LABEL,
                                y_label = _DEFAULT_EVIDENCE_LABEL):
        self.plotEvidences(png_file, True, False, True,
                           line_colours, line_styles, legend_pos, x_label,
                           y_label)

    def plotScaledLogEvidence(self, png_file,
                              line_colours = [],
                              line_styles = [],
                              legend_pos = _DEFAULT_LEGEND_POS,
                              x_label = _DEFAULT_EP_LABEL,
                              y_label = _DEFAULT_EVIDENCE_LABEL):
        self.plotEvidences(png_file, True, True, False,
                           line_colours, line_styles, legend_pos, x_label,
                           y_label)

    def plotScaledLogEvidenceRatio(self, png_file,
                                   line_colours = [],
                                   line_styles = [],
                                   legend_pos = _DEFAULT_LEGEND_POS,
                                   x_label = _DEFAULT_EP_LABEL,
                                   y_label = _DEFAULT_EVIDENCE_LABEL):
        self.plotEvidences(png_file, True, True, True,
                           line_colours, line_styles, legend_pos, x_label,
                           y_label)

    def squareDiff(self, x, j):
        """
        Called from computeScales(), this method returns the sum of squared
        difference between an evidence curve for a metric and the evidence curve
        for the first metric.
        """
        thissum = 0.0
        for i in range(self.epsteps + 1):
            indx = int(x * i)
            if(indx > self.epsteps):
                diff = self.evidences[0][i] - 1.0
            else:
                diff = (self.evidences[0][i] - self.evidences[j][indx])
            thissum += diff * diff
        return(thissum)

    def logSquareDiff(self, x, j):
        """
        Called from computeScales(), this method returns the sum of squared
        difference between a log-evidence curve for a metric and the log-
        evidence curve for the first metric.
        """
        thissum = 0.0
        for i in range(1, self.epsteps + 1):
            indx = int(x * i)
            if(indx > self.epsteps):
                diff = self.logevidences[0][i]
            else:
                diff = (self.logevidences[0][i] - self.logevidences[j][indx])
            thissum += diff * diff
        return(thissum)

    def computeScales(self):
        """
        Finds the epsilon scaling factor at which the sum of squared difference
        between the evidence (and log-evidence) curve for each metric and the
        first metric is minimized.

        It's not really needed if the maximum and minimum values for each metric
        are provided, which they are. However, if you don't have minimum and
        maximum values that make sense, this approach can be used instead -- and
        when creating the BruteABC object, the rescale argument should be set to
        True.
        """
        if(not self.rescale):
            self.scales_computed = True

        if(not self.scales_computed):
            for i in range(len(self.headers)):
                self.initscales[i] = 1.0 * (max(np.fabs(self.df[self.headers[i]])))

            for j in range(self.n_metrics):
                res = op.minimize_scalar(self.squareDiff, args = j)
                self.optscales[j] = res.x
                logres = op.minimize_scalar(self.logSquareDiff, args = j,
                                            bounds = (_LOGRES_LOWER_BOUND,
                                                      _LOGRES_UPPER_BOUND),
                                            method = 'bounded')
                self.logoptscales[j] = logres.x
        self.scales_computed = True

    def trianglePlots(self, file_name):
        """
        Save triangle plots of the posteriors to the file_name.
        """
        self.computeScales()
        for j in range(self.n_metrics):
#            postsamples = self.df[np.fabs(self.df[self.headers[j]])
#                                  < self.refeps * self.initscales[j] * self.logoptscales[j] ]
            postsamples = self.df[np.fabs(self.targets[self.headers[j]])
                                  < self.refeps * self.initscales[j] * self.logoptscales[j]]
            plotsamps = np.array(postsamples[self.params])[:, 0:len(self.params)]
            if len(plotsamps[:, 0]) > len(self.params):
                fig = triangle.corner(plotsamps, labels = self.params)
                fig.savefig(self.mkname(file_name), dpi = 150)
                plt.close()
            else:
                print "Number of valid samples (", len(plotsamps[:, 0]), \
                ") for metric", j + 1, \
                "is too small to make a plot, skipping....."

    def posteriorPlots(self, file_stem, suffix, y_label = _DEFAULT_EVIDENCE_LABEL):
        """
        Save plots of the posteriors (as histograms), one per parameter
        to a file name composed as file_stem_parameter.png
        """
        barcolours = [_DEFAULT_LINE_COLOURS[i] for i in range(self.n_metrics)]
        self.computeScales()
        for j in range(self.n_metrics):
#            postsamples = self.df[np.fabs(self.df[self.headers[j]])
#                                  < self.refeps * self.initscales[j] * self.logoptscales[j] ]
            postsamples = self.df[np.fabs(self.targets[self.headers[j]])
                                  < self.refeps * self.initscales[j] * self.logoptscales[j]]
            plotsamps = np.array(postsamples[self.params])[:, 0:len(self.params)]
            for k in range(len(self.params)):
                plt.figure(k + 1)
                if len(plotsamps[:, 0]) > len(self.params):
                    plt.hist(plotsamps[:,k], 50,
                             label = 'Metric %i (%s)'%(j + 1, self.disp_metrics[j]),
                             alpha = 0.5, normed = True, color = barcolours[j])

        for k in range(len(self.params)):
            plt.figure(k + 1)
            plt.legend(loc = 'lower right', shadow = False, fontsize = _DEFAULT_FONT_SIZE,
                       framealpha = 0.75)
            plt.title('Posterior comparison: %s'%(self.disp_params[k]))
            plt.xlabel(self.disp_params[k])
            plt.ylabel(y_label)
            plt.savefig(self.mkname('%s_%s.%s'%(file_stem, self.params[k], suffix)))

    @staticmethod
    def mkname(filename):
        rename = filename
        for chr in ";:<>?/\\\"\'|`{}[]#$^&*()":
            rename = rename.replace(chr, "_")
        return(rename)

    @staticmethod
    def ckdata(df, params, metrics, dffile, paramfile, metricfile, die = True):
        pnames = [params['parameter'][i] for i in range(len(params))]
        mnames = [metrics['metric'][i] for i in range(len(metrics))]
        dfnames = [df.columns[i] for i in range(len(df.columns))]
        for name in pnames:
            if(dfnames.count(name) == 0):
                sys.stderr.write("Parameter name %s in parameter file %s "%(name, paramfile)
                                 + "does not appear as a column heading in "
                                 + "run data file %s\n"%(dffile))
                if(die):
                    sys.exit(1)
                return(False)
            if(dfnames.count(name) > 1):
                sys.stderr.write("Parameter name %s in parameter file %s "%(name, paramfile)
                                 + "appears more than once as a column heading "
                                 + "in run data file %s\n"%(dffile))
                if(die):
                    sys.exit(1)
                return(False)

        for name in mnames:
            if(dfnames.count(name) == 0):
                sys.stderr.write("Metric name %s in metric file %s "%(name, metricfile)
                                 + "does not appear as a column heading in "
                                 + "run data file %s\n"%(dffile))
                if(die):
                    sys.exit(1)
                return(False)
            if(dfnames.count(name) > 1):
                sys.stderr.write("Metric name %s in metric file %s "%(name, metricfile)
                                 + "appears more than once as a column heading "
                                 + "in run data file %s\n"%(dffile))
                if(die):
                    sys.exit(1)
                return(False)

        return(True)

class Param:
    analyses = dict()

    def __init__(self, parameter, display, typestr, setting, minimum, maximum):
        self.parameter = parameter
        self.display = display
        self.typestr = typestr
        self.setting = setting
        self.minimum = minimum
        self.maximum = maximum
        self.isNumeric = (self.typestr == 'numeric')
        self.isDynamic = (self.isNumeric and (self.minimum < self.maximum))
        self.isConstant = (self.minimum == self.maximum)
        self.done_analysis = False
        self.isInt = False
        self.dfMin = None
        self.dfMax = None

    def analyse(self, df):
        if(not self.done_analysis):
            self.isInt = True
            for i in range(len(df)):
                if(self.typestr == 'numeric'):
                    num = df.loc[i, self.parameter]
                    if(num != int(num)):
                        self.isInt = False
                    if(i == 0):
                        self.dfMin = num
                        self.dfMax = num
                    else:
                        if num < self.dfMin:
                            self.dfMin = num
                        if num > self.dfMax:
                            self.dfMax = num
                else:
                    self.isInt = False
            self.done_analysis = True
            Param.analyses[self.parameter] = self
        elif(self.parameter in analyses):
            other = Param.analyses[self.parameter]
            self.isInt = other.isInt
            self.dfMin = other.dfMin
            self.dfMax = other.dfMax
            self.done_analysis = True

    def reanalyse(self, df):
        self.done_analyis = False
        if self.parameter in Param.analyses:
            del analyses[self.parameter]
        return(self.analyse(df))

    @staticmethod
    def read(file):
        paramdata = pd.read_csv(file, sep = ",", header = 0)
        return([Param(paramdata['parameter'][i],
                      paramdata['display'][i],
                      paramdata['type'][i],
                      paramdata['setting'][i],
                      paramdata['minimum'][i],
                      paramdata['maximum'][i]) for i in range(len(paramdata))])


class ParamOption:
    assignees = dict()

    def __init__(self, file, exclusive = False):
        self.paramdf = pd.read_csv(file, sep = ",", header = 0)
        self.param = Param.read(file)
        self.file = file
        self.name = self.file[:-4]
        if(self.name[:6] == 'param-'):
            self.name = self.name[6:]
        self.exclusive = exclusive

    def setName(name):
        self.name = name

    def select(self, df):
        s = df.assign(row_id = range(len(df)))
        if self.exclusive:
            not_already = [s.loc[s.index[j], 'row_id'] not in ParamOption.assignees for j in range(len(s))]
            s = s[not_already]
        for k in range(len(self.param)):
            if(self.param[k].isNumeric):
                if(self.param[k].isConstant):
                    s = s[s[self.param[k].parameter] == self.param[k].minimum]
                else:
                    self.param[k].analyse(df)
                    if(self.param[k].isInt):
                        s = s[(s[self.param[k].parameter] >= self.param[k].minimum)
                              & (s[self.param[k].parameter] <= self.param[k].maximum)]
                    else:
                        s = s[(s[self.param[k].parameter] > self.param[k].minimum)
                              & (s[self.param[k].parameter] < self.param[k].maximum)]
            else:
                s = s[(s[self.param[k].parameter] == self.param[k].minimum)
                      | (s[self.param[k].parameter] == self.param[k].maximum)
                      | (s[self.param[k].parameter] == self.param[k].setting)]
            # print("Combination %s: %d rows after parameter %s in range [%g, %g]"%(
            #     self.file, len(s), self.param['parameter'][k],
            #     self.param['minimum'][k], self.param['maximum'][k]
            # ))
        print("Combination %s: %d rows"%(self.file, len(s)))

        for j in range(len(s)):
            if s.loc[s.index[j], 'row_id'] not in ParamOption.assignees:
                ParamOption.assignees[s.loc[s.index[j], 'row_id']] = self
        return(s)

    def abc(self, df, metrics):
        s = self.select(df)
        if(len(s) > 0):
            abc = BruteABC(s, self.paramdf, metrics)
        else:
            abc = None
        return(abc)

    @staticmethod
    def buildarray(filenames):
        exclusive = False
        value = list()
        for i in range(len(filenames)):
            if filenames[i] == 'exclusive':
                exclusive = True
            else:
                value.append(ParamOption(filenames[i], exclusive))

        return(value)

    @staticmethod
    def plotarray(paramopts, data, metrics, image_file,
                  scaled = True, log = False, ratio = True,
                  line_colours = [],
                  legend_pos = _DEFAULT_LEGEND_POS,
                  x_label = _DEFAULT_EP_LABEL,
                  y_label = _DEFAULT_EVIDENCE_LABEL,
                  font_size = _DEFAULT_FONT_SIZE):

        if line_colours == []:
            line_colours = _DEFAULT_LINE_COLOURS

        abcs = [paramopts[i].abc(data, metrics) for i in range(len(paramopts))]

        for j in range(len(metrics)):
            for i in range(len(abcs)):
                if(not abcs[i] is None):
                    xdata = abcs[i].getEpsilons(j, scaled, log)
                    data = abcs[i].getEvidences(j, log, ratio)
                    plt.plot(xdata, (data), linewidth = 2,
                            linestyle = '-', color = line_colours[i],
                            label = paramopts[i].name)

            plt.title('Metric %i (%s)'%(j + 1, metrics['display'][j]))
            plt.xlabel(x_label)
            plt.ylabel(y_label)
            legend = plt.legend(loc = legend_pos, shadow = False, frameon = False,
                                fontsize = font_size) #, markerfirst = False)
            if not log:
                plt.plot([0, 1], [1, 1], linestyle = 'dashed', color = '#000000')
            plt.xlim([0, 1])
            plt.savefig(BruteABC.mkname('%s_%s.%s'%(image_file[:-4],
                        metrics['metric'][j], image_file[-3:])))
            plt.close()


if __name__ == "__main__":
    if(len(sys.argv) < 2):
        sys.stderr.write("Usage: bruteABC.py calibrate <run data> <metrics file> "
                         + "<parameter file> <save evidence file> "
                         + "<save evidence ratio file> [<plot log evidence "
                         + "ratio file> <plot evidence ratio file> <triangle "
                         + "plots file> <posterior plots file (no suffix)>]\n")
        sys.stderr.write("\nOR   : bruteABC.py compare <run data> <metrics file> "
                         + "<plot evidence ratio file> <parameter files...>\n")
        sys.exit(1)

    if(sys.argv[1] == 'calibrate'):

        if(len(sys.argv) != 7 and len(sys.argv) != 11):
            sys.stderr.write("Usage: bruteABC.py calibrate <run data> <metrics file> "                     + "<parameter file> <save evidence file> "
                             + "<parameter file> <save evidence file> "
                             + "<save evidence ratio file> [<plot log evidence "
                             + "ratio file> <plot evidence ratio file> <triangle "
                             + "plots file> <posterior plots file (no suffix)>]\n")
            sys.exit(1)


        if(not os.path.exists(sys.argv[2])):
            sys.stderr.write("Run data file %s does not exist\n"%(sys.argv[2]))
            sys.exit(1)

        if(not os.path.exists(sys.argv[3])):
            sys.stderr.write("Metrics file %s does not exist\n"%(sys.argv[3]))
            sys.exit(1)

        if(not os.path.exists(sys.argv[4])):
            sys.stderr.write("Parameter list file %s does not exist\n"%(sys.argv[4]))
            sys.exit(1)

        df = pd.read_csv(sys.argv[2], sep = ',', header = 0)
        metrics = pd.read_csv(sys.argv[3], sep = ',', header = 0)
        params = pd.read_csv(sys.argv[4], sep = ',', header = 0)

        BruteABC.ckdata(df, params, metrics, sys.argv[2], sys.argv[4], sys.argv[5])

        brute = BruteABC(df, params, metrics)
        brute.saveEvidences(sys.argv[5])
        brute.saveEvidenceRatios(sys.argv[6])

        if(len(sys.argv) == 11):
            suffix = (sys.argv[7])[-3:]
            brute.plotScaledLogEvidenceRatio(sys.argv[7])
            brute.plotScaledEvidenceRatio(sys.argv[8])
            brute.trianglePlots(sys.argv[9])
            brute.posteriorPlots(sys.argv[10], suffix)

    if(sys.argv[1] == 'compare'):

        if(len(sys.argv) < 6):
            sys.stderr.write("Usage: bruteABC.py compare <run data> <metrics file> "
                             + "<plot evidence ratio file> <parameter files...>\n")
            sys.exit(1)


        if(not os.path.exists(sys.argv[2])):
            sys.stderr.write("Run data file %s does not exist\n"%(sys.argv[2]))
            sys.exit(1)

        if(not os.path.exists(sys.argv[3])):
            sys.stderr.write("Metrics file %s does not exist\n"%(sys.argv[3]))
            sys.exit(1)

        df = pd.read_csv(sys.argv[2], sep = ',', header = 0)
        metrics = pd.read_csv(sys.argv[3], sep = ",", header = 0)
        plotfile = sys.argv[4]
        params = ParamOption.buildarray(sys.argv[5:])

        for i in range(len(params)):
            BruteABC.ckdata(df, params[i].paramdf, metrics,
                            sys.argv[2], sys.argv[5 + i], sys.argv[3])

        ParamOption.plotarray(params, df, metrics, plotfile)

    sys.exit(0)
