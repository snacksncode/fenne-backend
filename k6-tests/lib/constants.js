// Valid enum values for API requests
// These match the Rails API validation schemas

export const MEAL_TYPES = ['breakfast', 'lunch', 'dinner'];

export const UNITS = [
  'g', 'kg', 'ml', 'l', 'fl_oz', 'cup',
  'tbsp', 'tsp', 'pt', 'qt', 'oz', 'lb', 'count'
];

export const AISLES = [
  'produce', 'bakery', 'dairy_eggs', 'meat', 'seafood',
  'pantry', 'frozen_foods', 'beverages', 'snacks',
  'condiments_sauces', 'spices_baking', 'household',
  'personal_care', 'pet_supplies', 'other'
];

export const GROCERY_STATUS = ['pending', 'completed'];

export const SCHEDULE_ITEM_TYPES = ['recipe', 'dining_out'];
