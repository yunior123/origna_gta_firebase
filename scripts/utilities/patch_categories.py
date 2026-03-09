"""Module patch_categories.py."""
import re

with open('origna_gta/lib/core/schema/schema_constants.dart', 'r') as f:
    content = f.read()

new_by_id = """
  static const Map<int, List<String>> _byId = {
    1: ['Smartphones', 'Laptops', 'Tablets', 'Cameras', 'Audio', 'Gaming', 'Smart Home', 'Wearables'], // Electronics
    2: ['Laptops', 'Desktops', 'Monitors', 'Components', 'Networking', 'Accessories'], // Computers
    3: ['Consoles', 'Video Games', 'Controllers', 'Headsets', 'PC Gaming', 'VR'], // Gaming
    4: ['Furniture', 'Decor', 'Kitchen', 'Bedding', 'Lighting', 'Garden & Outdoor', 'Storage'], // Home & Kitchen
    5: ["Men's Clothing", "Women's Clothing", "Kids' Clothing", 'Outerwear', 'Activewear', 'Underwear'], // Fashion
    6: ['Sneakers', 'Boots', 'Sandals', 'Bags', 'Belts', 'Hats', 'Sunglasses'], // Shoes & Accessories
    7: ['Watches', 'Necklaces', 'Rings', 'Earrings', 'Bracelets', 'Fine Jewelry'], // Jewelry & Watches
    8: ['Skincare', 'Haircare', 'Makeup', 'Fragrance', "Men's Grooming"], // Beauty & Personal Care
    9: ['Vitamins & Supplements', 'Medical Devices', 'Personal Care', 'Diet & Nutrition'], // Health & Wellness
    10: ['Fitness', 'Outdoor Recreation', 'Team Sports', 'Water Sports', 'Winter Sports', 'Cycling'], // Sports & Fitness
    11: ['Car Accessories', 'Motorcycle', 'Tools & Equipment', 'Replacement Parts', 'Car Care'], // Automotive
    12: ['Power Tools', 'Hand Tools', 'Hardware', 'Plumbing', 'Electrical', 'Building Materials'], // Tools & Hardware
    13: ['Pens & Pencils', 'Paper', 'Binders & Folders', 'Desk Accessories', 'Printers & Ink', 'School Supplies'], // Office Supplies
    14: ['Fiction', 'Non-Fiction', 'Children', 'Textbooks', 'Comics & Graphic Novels', 'Audiobooks'], // Books
    15: ['Guitars', 'Keyboards', 'Drums', 'Recording Equipment', 'DJ Gear', 'Accessories'], // Music & Instruments
    16: ['Puzzles & Board Games', 'Building Toys', 'Dolls & Playsets', 'Action Figures', 'Outdoor Play'], // Toys & Games
    17: ['Baby Clothing', 'Feeding', 'Nursery', 'Strollers', 'Toys', 'Diapering'], // Baby & Kids
    18: ['Dogs', 'Cats', 'Fish', 'Birds', 'Small Animals', 'Reptiles'], // Pet Supplies
    19: ['Snacks', 'Beverages', 'Health Foods', 'Specialty Foods', 'Baking', 'Pantry Staples'], // Groceries
    20: ['Painting', 'Sculpture', 'Photography', 'Mixed Media', 'Antiques', 'Coins & Stamps'], // Art & Collectibles
    21: ['Software', 'eBooks', 'Digital Art', 'Audio & Music', 'Courses & Tutorials', 'Templates'], // Digital Products
  };
"""

content = re.sub(r'static const Map<int, List<String>> _byId = \{.*?\};', new_by_id.strip(), content, flags=re.DOTALL)

with open('origna_gta/lib/core/schema/schema_constants.dart', 'w') as f:
    f.write(content)
