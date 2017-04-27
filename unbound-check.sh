#! /usr/bin/env bash

drill  -DQ -p 553 NS . @127.0.0.1 && \
drill -tDQ -p 553 NS . @127.0.0.1
