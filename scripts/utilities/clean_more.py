"""Module clean_more.py."""
with open('STATE.md', 'r') as f:
    lines = f.read().split('\n')

fixed_bugs = ['FE-L1', 'FE-L2', 'LEG-L2']
new_lines = [line for line in lines if not any(line.strip().startswith(f"- **{bug}**") for bug in fixed_bugs)]

with open('STATE.md', 'w') as f:
    f.write('\n'.join(new_lines))

print("Removed FE-L1, FE-L2, and LEG-L2 from STATE.md")
