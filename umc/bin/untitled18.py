#!/usr/bin/env python2
# -*- coding: utf-8 -*-
"""
Created on Mon Apr 16 13:39:58 2018

@author: rstyczynski
"""

import yaml

yamlFile='/Users/rstyczynski/Documents/IKEA/11.Test/TESTS/10.04.2018/umc_archive/rodmon_data/info/meminfo.info'
getData='meminfo.metrics'


with open(yamlFile, 'r') as yamlDoc:
    doc = yaml.load(yamlDoc)
    
finalDoc=doc
for cfgElement in getData.split('.'):
    finalDoc = finalDoc[cfgElement]

for group in finalDoc:
    print 
    print '---'
    print group
    getData='meminfo.metrics.' + group
    columns=doc
    for cfgElement in getData.split('.'):
        columns = columns[cfgElement]
    for column in columns:
        print column,

