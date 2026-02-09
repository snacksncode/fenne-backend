import { MEAL_TYPES, UNITS, AISLES, GROCERY_STATUS } from './constants.js';

/**
 * Test data generator class
 * Creates realistic, random test data for load testing
 */
export class DataGenerator {
  /**
   * Generate unique email address for testing
   * @returns {string} - Unique email like test-1706123456789-abc123@k6test.com
   */
  static generateEmail() {
    const timestamp = Date.now();
    const random = Math.random().toString(36).substring(7);
    return `test-${timestamp}-${random}@k6test.com`;
  }

  /**
   * Generate random secure password
   * @returns {string} - Random password like Pass1a2b3c4d!123
   */
  static generatePassword() {
    return `Pass${Math.random().toString(36).substring(2, 10)}!123`;
  }

  /**
   * Generate random name
   * @returns {string} - Random full name
   */
  static generateName() {
    const firstNames = ['Alice', 'Bob', 'Charlie', 'Diana', 'Eve', 'Frank', 'Grace', 'Henry', 'Ivy', 'Jack'];
    const lastNames = ['Smith', 'Johnson', 'Williams', 'Brown', 'Jones', 'Garcia', 'Miller', 'Davis', 'Rodriguez', 'Martinez'];
    const firstName = firstNames[Math.floor(Math.random() * firstNames.length)];
    const lastName = lastNames[Math.floor(Math.random() * lastNames.length)];
    return `${firstName} ${lastName}`;
  }

  /**
   * Generate recipe data with ingredients
   * @returns {object} - Recipe data in API format
   */
  static generateRecipe() {
    const recipes = [
      'Pasta Carbonara', 'Grilled Salmon', 'Chicken Curry',
      'Vegetable Stir Fry', 'Beef Tacos', 'Caesar Salad',
      'Mushroom Risotto', 'Thai Green Curry', 'Pulled Pork',
      'Margherita Pizza', 'Fish and Chips', 'Pad Thai'
    ];
    const recipeName = `${recipes[Math.floor(Math.random() * recipes.length)]} (${Date.now()})`;

    // Generate 3-7 ingredients
    const ingredientCount = Math.floor(Math.random() * 5) + 3;
    const ingredients = [];

    const ingredientNames = [
      'Pasta', 'Eggs', 'Bacon', 'Parmesan', 'Garlic', 'Olive Oil',
      'Salmon', 'Lemon', 'Dill', 'Chicken', 'Coconut Milk', 'Curry Paste',
      'Rice', 'Soy Sauce', 'Ginger', 'Bell Pepper', 'Onion', 'Tomato',
      'Mushrooms', 'Butter', 'Cream', 'Pork', 'BBQ Sauce', 'Mozzarella'
    ];

    for (let i = 0; i < ingredientCount; i++) {
      ingredients.push({
        name: ingredientNames[Math.floor(Math.random() * ingredientNames.length)],
        quantity: Math.round((Math.random() * 10 + 0.5) * 10) / 10, // 0.5 - 10.5, rounded to 1 decimal
        unit: UNITS[Math.floor(Math.random() * UNITS.length)],
        aisle: AISLES[Math.floor(Math.random() * AISLES.length)],
      });
    }

    // Select 1-2 meal types
    const mealTypeCount = Math.floor(Math.random() * 2) + 1;
    const selectedMealTypes = [];
    const shuffledMealTypes = [...MEAL_TYPES].sort(() => 0.5 - Math.random());

    for (let i = 0; i < mealTypeCount; i++) {
      selectedMealTypes.push(shuffledMealTypes[i]);
    }

    return {
      data: {
        name: recipeName,
        meal_types: selectedMealTypes,
        time_in_minutes: Math.floor(Math.random() * 90) + 15, // 15-105 minutes
        liked: Math.random() > 0.5,
        ingredients: ingredients,
      }
    };
  }

  /**
   * Generate grocery item data
   * @returns {object} - Grocery item data in API format
   */
  static generateGroceryItem() {
    const items = [
      'Milk', 'Bread', 'Eggs', 'Cheese', 'Apples',
      'Bananas', 'Chicken Breast', 'Ground Beef', 'Rice', 'Pasta',
      'Yogurt', 'Butter', 'Carrots', 'Lettuce', 'Tomatoes'
    ];

    return {
      data: {
        name: items[Math.floor(Math.random() * items.length)],
        quantity: Math.floor(Math.random() * 10) + 1, // 1-10
        aisle: AISLES[Math.floor(Math.random() * AISLES.length)],
        unit: UNITS[Math.floor(Math.random() * UNITS.length)],
        status: GROCERY_STATUS[Math.floor(Math.random() * GROCERY_STATUS.length)],
      }
    };
  }

  /**
   * Generate schedule entry for a specific date
   * @param {string|null} recipeId - Optional recipe ID to use in meals
   * @returns {object} - Schedule data with meals
   */
  static generateScheduleEntry(recipeId = null) {
    const meals = {};
    const numMeals = Math.floor(Math.random() * 3) + 1; // 1-3 meals

    const mealTypes = ['breakfast', 'lunch', 'dinner'];
    for (let i = 0; i < numMeals; i++) {
      const mealType = mealTypes[i];
      const isDiningOut = Math.random() > 0.7; // 30% chance of dining out

      if (isDiningOut) {
        meals[mealType] = {
          type: 'dining_out',
          name: 'Restaurant',
        };
      } else if (recipeId) {
        meals[mealType] = {
          type: 'recipe',
          recipe_id: recipeId,
        };
      }
    }

    return {
      ...meals,
      is_shopping_day: Math.random() > 0.8, // 20% chance of shopping day
    };
  }

  /**
   * Generate date range (YYYY-MM-DD format)
   * @param {number} daysFromNow - Days offset from today
   * @param {number} durationDays - Number of days in the range
   * @returns {object} - { start: string, end: string }
   */
  static generateDateRange(daysFromNow = 0, durationDays = 7) {
    const startDate = new Date();
    startDate.setDate(startDate.getDate() + daysFromNow);

    const endDate = new Date(startDate);
    endDate.setDate(endDate.getDate() + durationDays - 1);

    return {
      start: startDate.toISOString().split('T')[0],
      end: endDate.toISOString().split('T')[0],
    };
  }

  /**
   * Generate single date (YYYY-MM-DD format)
   * @param {number} daysFromNow - Days offset from today
   * @returns {string} - Date in YYYY-MM-DD format
   */
  static generateDate(daysFromNow = 0) {
    const date = new Date();
    date.setDate(date.getDate() + daysFromNow);
    return date.toISOString().split('T')[0];
  }
}
