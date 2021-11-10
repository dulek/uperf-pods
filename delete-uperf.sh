#!/bin/bash

oc delete job uperf-client
oc delete cm uperf-profile
oc delete deploy uperf-server
