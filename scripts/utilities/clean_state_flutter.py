"""Module clean_state_flutter.py."""
import re

with open('STATE.md', 'r') as f:
    content = f.read()

# Define the IDs of bugs that are listed as fixed
fixed_bugs = [
    'SCH-C1', 'SCH-C2', 'SCH-C3', 'LEG-H3', 'PAY-C1', 'PAY-C2', 'PAY-C3',
    'EMAIL-C1', 'EMAIL-C2', 'EMAIL-C3', 'EMAIL-C4', 'STOCK-C1', 'ADDR-C1',
    'EMAIL-H1', 'EMAIL-H2', 'EMAIL-H3', 'EMAIL-H4', 'CRON-M1', 'PROD-C1',
    'PROD-C2', 'PROD-C3', 'PROD-C4', 'BOOT-C1', 'FE-H1', 'FE-M1', 'NOTIF-M1',
    'NOTIF-M2', 'CHAT-C1', 'CHAT-C2', 'CHAT-H1', 'CHAT-H2', 'CHAT-H3',
    'BOOT-H2', 'BOOT-H3', 'BOOT-M3', 'WH-H1', 'WH-H2', 'STOCK-M1', 'ADDR-M1',
    'CHAT-M2', 'CRON-C1', 'CRON-C2', 'CRON-C3', 'FE-M3', 'LEG-H1', 'LEG-H2',
    'SRCH-C1', 'SRCH-H1', 'SRCH-H2', 'SRCH-H3', 'CRON-H1', 'CRON-H2',
    'BOOT-H1', 'BOOT-M1', 'BOOT-M2', 'BOOT-M4', 'BOOT-L1', 'BOOT-L2',
    'CRON-L1', 'FAV-L2', 'FAV-M2', 'FE-M2', 'LEG-L1', 'NOTIF-H1', 'NOTIF-H2',
    'PAY-M3', 'ADDR-L1', 'ADDR-M2', 'ADDR-M3', 'SCH-M1', 'QA-C1', 'STOCK-H1',
    'WH-C1', 'IDX-C1'
]

lines = content.split('\n')
new_lines = []

for line in lines:
    skip = False
    for bug in fixed_bugs:
        if line.strip().startswith(f"- **{bug}**"):
            skip = True
            break
    if not skip:
        new_lines.append(line)

with open('STATE.md', 'w') as f:
    f.write('\n'.join(new_lines))

print("Cleaned STATE.md")
