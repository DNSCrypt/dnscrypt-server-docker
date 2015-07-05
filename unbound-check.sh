#! /bin/sh

drill  -DQ NS . @127.0.0.1 &&
drill -tDQ NS . @127.0.0.1
