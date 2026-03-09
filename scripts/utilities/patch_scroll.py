"""Module patch_scroll.py."""

with open('origna_gta/lib/screens/home_screen.dart', 'r') as f:
    content = f.read()

content = content.replace("ListView.builder(\n        scrollDirection: Axis.horizontal,", "ListView.builder(\n        physics: const ClampingScrollPhysics(),\n        scrollDirection: Axis.horizontal,")
content = content.replace("ListView.builder(\n          scrollDirection: Axis.horizontal,", "ListView.builder(\n          physics: const ClampingScrollPhysics(),\n          scrollDirection: Axis.horizontal,")

with open('origna_gta/lib/screens/home_screen.dart', 'w') as f:
    f.write(content)
