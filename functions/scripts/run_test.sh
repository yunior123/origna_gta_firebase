#!/bin/bash
source functions/venv/bin/activate
pip install requests boto3
python functions/test_r2_simple.py
