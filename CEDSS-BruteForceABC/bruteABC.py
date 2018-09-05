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

class BruteABC:
    """BruceABC class

    Compute the evidence ratio given some data
    """
    def __init__(self, df, params, metrics, epsteps = 100, maxep = 1.0):
        self.df = df
        self.params = params
        self.metrics = metrics
        self.headers = sorted(metrics.keys())
        self.calibvals = [metrics[key]['target'] for key in headers]
        self.minima = [metrics[key]['minimum'] for key in headers]
        self.maxima = [metrics[key]['maximum'] for key in headers]
        self.difima = [self.maxima[i] - self.minima[i] for i in len(self.headers)]
        self.epsteps = epsteps
        self.epsilons = [1.0 * (maxep / epsteps) * i for i in range(epsteps + 1)]
        self.n_metrics = len(metrics)
        self.evidences = np.zeros(n_metrics * (epsteps + 1))
        self.evidences = self.evidences.reshape(n_metrics, epsteps + 1)
        self.evratio = np.zeros(n_metrics * (epsteps + 1))
        self.evratio = self.evratio.reshape(n_metrics, epsteps + 1)
        self.logevidences = np.zeros(n_metrics * (epsteps + 1))
        self.logevidences = self.logevidences.reshape(n_metrics, epsteps + 1)
        self.moments = 1.0 * np.zeros_like(self.calibvals)
        self.optscales = 1.0 * np.ones_like(self.calibvals)
        self.logoptscales = 1.0 * np.ones_like(self.calibvals)

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

if __name__ == "__main__":
    df = pd.read_csv(sys.args[1], sep = ',', header = 0)
    metrics = pd.read_csv(sys.args[2], sep = ',', header = 0)
    params = sys.args[3:(len(sys.args))]

    brute = BruteABC(df, params, metrics)
