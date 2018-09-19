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

   The first line should be 'metric,target,minimum,maximum'

   One row for each metric. The metric name should match exactly one column
   heading in the data file. The target is the target value for the metric
   -- i.e. the value it would have if the model perfectly fitted the data.
   The minimum is the minimum 'reasonable' value; the maximum is the maximum
   'reasonable' value. The minimum and maximum are used to scale each metric
   so that the multiple metrics are comparable with each other.

3. A parameter metadata file in CSV format with column headings:

   The first line should be 'param,minimum,maximum'

   One row for each parameter. The parameter name should match exactly one
   column heading in the data file. The minimum and maximum values are
   ignored, but can be used to specify the values explored in runs of
   the model.

Outputs:

1. A CSV file with one column for epsilon values, and one column for each
   metric and combination thereof, and one column for each model version,
   with rows showing the evidence ratios for each model version and epsilon
   and metric/metric combination.

Authors: Jonathan Gair (University of Edinburgh)
         and Gary Polhill (The James Hutton Institute)
Date: 5 September 2018
Uses: numpy, scipy, pandas
Licence: GNU General Public Licence v3 (see comments)
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
__author__ = "Gary Polhill & Jonathan Gair"
# Imports: There are quite a lot of these, and many are only needed for
# visualization, which should be handled by a separate module. Minimum
# imports needed are sys, numpy and pandas. We may need scipy/optimize too,
# depending on how the epsilon scaling issue is resolved.
import sys
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import corner as triangle
from scipy import optimize as op
from collections import Counter

# Globals that are local to this file

_DEFAULT_EPSTEPS = 100
_DEFAULT_MAXEP = 1.0
_DEFAULT_LEGEND_POS = 'upper right'
_DEFAULT_EP_LABEL = r'$\epsilon_i$'
_DEFAULT_EVIDENCE_LABEL = r'${\cal Z}$'
_LOGRES_LOWER_BOUND = 0
_LOGRES_UPPER_BOUND = 10
_DEFAULT_LINE_COLOURS = ['#a6cee3', '#1f78b4', '#b2df8a', '#33a02c', '#fb9a99',
                         '#e31a1c', '#fdbf6f', '#ff7f00', '#cab2d6', '#6a3d9a',
                         '#b15928', '#ffff99']  # From colour brewer
_DEFAULT_LINE_STYLE = '-'

class BruteABC:
    """BruceABC class

    Compute the evidence ratio given some data, and provide various utilities
    for saving and plotting the data.
    """
    def __init__(self, df, params, metrics, epsteps = _DEFAULT_EPSTEPS,
                 maxep = _DEFAULT_MAXEP, rescale = False):
        self.df = df
        self.params = sorted(params.keys())
        self.metrics = metrics
        self.headers = sorted(metrics.keys())
        self.calibvals = [metrics[key]['target'] for key in headers]
        self.minima = [metrics[key]['minimum'] for key in headers]
        self.maxima = [metrics[key]['maximum'] for key in headers]
        self.difima = [self.maxima[i] - self.minima[i] for i in len(self.headers)]
        self.epsteps = epsteps
        self.epsilons = [1.0 * (maxep / epsteps) * i for i in range(epsteps + 1)]
        self.refeps = self.epsilons[1]
        self.n_metrics = len(metrics)
        self.evidences = np.zeros(n_metrics * (epsteps + 1))
        self.evidences = self.evidences.reshape(n_metrics, epsteps + 1)
        self.evratio = np.zeros(n_metrics * (epsteps + 1))
        self.evratio = self.evratio.reshape(n_metrics, epsteps + 1)
        self.logevidences = np.zeros(n_metrics * (epsteps + 1))
        self.logevidences = self.logevidences.reshape(n_metrics, epsteps + 1)
        self.moments = 1.0 * np.zeros_like(self.calibvals)
        self.initscales = 1.0 * np.ones_like(self.calibvals)
        self.optscales = 1.0 * np.ones_like(self.calibvals)
        self.logoptscales = 1.0 * np.ones_like(self.calibvals)
        self.scales_computed = False

        for i in range(eptsteps + 1)
            for j in range(self.n_metrics)
                self.evidences[j][i]
                    = sum(1.0 for val in 1.0 * np.array(df[self.headers[j]])
                        if np.fabs((val - minima[j]) / self.difima[j])
                            < self.epsilons[i]) / 1.0 * len(df[self.headers[j]])
                if i > 0:
                    self.evratio[j][i] = self.evidences[j][i] / self.epsilons[i]
                self.moments[j] = self.moments[j] + evidences[j][i] * self.epsilons[i]
                if self.evidences[j][i] > 0.0:
                    self.logevidences[j][i] = np.log(self.evidences[j][i])
                    self.logmoments[j]
                        = self.logmoments[j] + self.logevidences[j][i] * self.epsilons[i]

    def saveEvidences(file_name: str, delimiter = ","):
        """
        Save the evidences to the file (CSV format by default)
        """
        outdata = np.array(np.reshape(self.epsilons, (self.epsteps + 1, 1)))
        for j in range(self.n_metrics):
            np.append(outdata, np.reshape(self.evidences[j], (self.epsteps + 1, 1)),
                      axis = 1)
        np.savetxt(file_name, outdata, delimiter = delimiter)

    def saveEvidenceRatios(file_name: str, delimiter = ","):
        """
        Save the evidence ratio to the file (CSV format by default)
        """
        outdata = np.array(np.reshape(self.epsilons, (self.epsteps + 1, 1)))
        for j in range(self.n_metrics):
            np.append(outdata, np.reshape(self.evratio[j], (self.epsteps + 1, 1)),
                      axis = 1)
        np.savetxt(file_name, outdata, delimiter = delimiter)

    def plotEvidences(image_file: str, scaled = True, log = False, ratio = True,
                      line_colours = [],
                      line_styles = [],
                      legend_pos = _DEFAULT_LEGEND_POS,
                      x_label = _DEFAULT_EP_LABEL,
                      y_label = _DEFAULT_EVIDENCE_LABEL):
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
            if scaled:
                if log:
                    xdata = np.array(self.epsilons) / self.logoptscales[j]
                else:       # not log
                    xdata = np.array(self.epsilons) / self.optscales[j]
            else:           # not scaled
                xdata = np.array(self.epsilons)

            if ratio:
                if log:
                    data = np.log(self.evratio[j])
                else:       # not log
                    data = self.evratio[j]
            else:           # not ratio
                if log:
                    data = np.log(self.evidences[j])
                else:       # not log
                    data = self.evidences[j]

            plt.plot(xdata, (data),
                     linestyle = line_styles[j], color = line_colours[j],
                     label='Metric %i'%(j + 1))
        plt.xlabel(x_label)
        plt.ylabel(y_label)
        legend = plt.legend(loc = legend_pos, shadow = True)
        plt.xlim([0, 1])
        plt.savefig(image_file)

    def plotEvidence(png_file: str,
                     line_colours = [],
                     line_styles = [],
                     legend_pos = _DEFAULT_LEGEND_POS,
                     x_label = _DEFAULT_EP_LABEL,
                     y_label = _DEFAULT_EVIDENCE_LABEL):
        self.plotEvidences(png_file, False, False, False,
                           line_colours, line_styles, legend_pos, x_label,
                           y_label)

    def plotEvidenceRatio(png_file: str,
                          line_colours = [],
                          line_styles = [],
                          legend_pos = _DEFAULT_LEGEND_POS,
                          x_label = _DEFAULT_EP_LABEL,
                          y_label = _DEFAULT_EVIDENCE_LABEL):
        self.plotEvidences(png_file, False, False, True,
                           line_colours, line_styles, legend_pos, x_label,
                           y_label)

    def plotLogEvidence(png_file: str,
                        line_colours = [],
                        line_styles = [],
                        legend_pos = _DEFAULT_LEGEND_POS,
                        x_label = _DEFAULT_EP_LABEL,
                        y_label = _DEFAULT_EVIDENCE_LABEL):
        self.plotEvidences(png_file, False, True, False,
                           line_colours, line_styles, legend_pos, x_label,
                           y_label)

    def plotLogEvidenceRatio(png_file: str,
                             line_colours = [],
                             line_styles = [],
                             legend_pos = _DEFAULT_LEGEND_POS,
                             x_label = _DEFAULT_EP_LABEL,
                             y_label = _DEFAULT_EVIDENCE_LABEL):
        self.plotEvidences(png_file, False, True, True,
                           line_colours, line_styles, legend_pos, x_label,
                           y_label)

    def plotScaledEvidence(png_file: str,
                           line_colours = [],
                           line_styles = [],
                           legend_pos = _DEFAULT_LEGEND_POS,
                           x_label = _DEFAULT_EP_LABEL,
                           y_label = _DEFAULT_EVIDENCE_LABEL):
        self.plotEvidences(png_file, True, False, False,
                           line_colours, line_styles, legend_pos, x_label,
                           y_label)

    def plotScaledEvidenceRatio(png_file: str,
                                line_colours = [],
                                line_styles = [],
                                legend_pos = _DEFAULT_LEGEND_POS,
                                x_label = _DEFAULT_EP_LABEL,
                                y_label = _DEFAULT_EVIDENCE_LABEL):
        self.plotEvidences(png_file, True, False, True,
                           line_colours, line_styles, legend_pos, x_label,
                           y_label)

    def plotScaledLogEvidence(png_file: str,
                              line_colours = [],
                              line_styles = [],
                              legend_pos = _DEFAULT_LEGEND_POS,
                              x_label = _DEFAULT_EP_LABEL,
                              y_label = _DEFAULT_EVIDENCE_LABEL):
        self.plotEvidences(png_file, True, True, False,
                           line_colours, line_styles, legend_pos, x_label,
                           y_label)

    def plotScaledLogEvidenceRatio(png_file: str,
                                   line_colours = [],
                                   line_styles = [],
                                   legend_pos = _DEFAULT_LEGEND_POS,
                                   x_label = _DEFAULT_EP_LABEL,
                                   y_label = _DEFAULT_EVIDENCE_LABEL):
        self.plotEvidences(png_file, True, True, True,
                           line_colours, line_styles, legend_pos, x_label,
                           y_label)

    def squareDiff(x, j):
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

    def logSquareDiff(x, j):
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
	            if(indx == 0):
                    indx = 1
	            diff = (self.logevidences[0][i] - self.logevidences[j][indx])
            thissum += diff * diff
        return(thissum)

    def computeScales():
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
        if(!self.rescale):
            self.scales_computed = True

        if(!self.scales_computed):
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

    def trianglePlots(file_name: str):
        """
        Save triangle plots of the posteriors to the file_name.
        """
        self.computeScales()
        for j in range(self.n_metrics):
            postsamples = self.df[np.fabs(self.df[self.headers[j]])
                                  < self.refeps * self.initscales[j] * self.logoptscales[j] ]
    	plotsamps = np.array(postsamples[self.params])[:, 0:len(self.params)]
    	if len(plotsamps[:, 0]) > len(self.params):
    	    fig = triangle.corner(plotsamps, labels = self.params)
    	    fig.savefig(file_name, dpi = 150)
    	else:
    	    print "Number of valid samples for metric ", j + 1,
                  " is too small to make a plot, skipping....."

    def posteriorPlots(file_stem: str):
        """
        Save plots of the posteriors (as histograms), one per parameter
        to a file name composed as file_stem_parameter.png
        """
        self.computeScales()
        for j in range(self.n_metrics)):
            postsamples = self.df[np.fabs(self.df[self.headers[j]])
                                  < self.refeps * self.initscales[j] * self.logoptscales[j] ]
            plotsamps = np.array(postsamples[self.params])[:, 0:len(self.params)]
            for k in range(len(self.params)):
                plt.figure(k + 1)
        	if len(plotsamps[:, 0]) > len(self.params):
        	    plt.hist(plotsamps[:,k], 50, label = 'metric %i'%(j + 1),
                         alpha = 0.5, normed = True)

        for k in range(len(self.params)):
            plt.figure(k + 1)
            plt.legend(loc = 'best', shadow = False)
            plt.title('Posterior comparison: %s'%(self.params[k]))
            plt.savefig('%s_%s.png'%(file_stem, params[k]))


if __name__ == "__main__":
    df = pd.read_csv(sys.args[1], sep = ',', header = 0)
    metrics = pd.read_csv(sys.args[2], sep = ',', header = 0)
    params = pd.read_csv(sys.args[3], sep = ',', header = 0)

    brute = BruteABC(df, params, metrics)
    brute.saveEvidences(sys.args[4])
    brute.saveEvidenceRatios(sys.args[5])

    if(len(sys.args) > 5):
        brute.plotScaledLogEvidenceRatios(sys.args[6])
        brute.plotScaledEvidenceRatios(sys.args[7])
        brute.trianglePlots(sys.args[8])
        brute.posteriorPlots(sys.args[9])

    sys.exit(0)
