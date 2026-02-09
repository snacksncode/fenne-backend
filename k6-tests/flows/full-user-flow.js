import { sleep } from 'k6';
import { AuthHelper } from '../lib/auth.js';
import { ApiClient } from '../lib/api-client.js';
import { DataGenerator } from '../lib/data-generators.js';
import { CONFIG } from '../lib/config.js';

/**
 * Complete user journey simulating realistic behavior:
 * 1. Signup
 * 2. Get user info
 * 3. Create recipes
 * 4. View recipes
 * 5. Add recipes to schedule
 * 6. Generate grocery list from schedule
 * 7. Manage grocery items
 * 8. Search for food items
 * 9. Checkout groceries
 * 10. Update recipe
 * 11. Logout
 */
export function fullUserFlow() {
  // 1. Signup - Create new user
  // const email = DataGenerator.generateEmail();
  // const password = DataGenerator.generatePassword();
  // const name = DataGenerator.generateName();

  // const { token } = AuthHelper.signup(email, password, name);
  // sleep(CONFIG.thinkTime.min);

  const token = 'be1f1113b495cc4f177fb750869a2bef5aa88187576657e3596fa7fbd34c0faa'
  const client = new ApiClient(token);

  // 2. Get initial state - Verify user is authenticated
  AuthHelper.getMe(token);
  sleep(CONFIG.thinkTime.min);

  // 3. Create 2-3 recipes
  const recipes = [];
  const recipeCount = Math.floor(Math.random() * 2) + 2; // 2-3 recipes

  for (let i = 0; i < recipeCount; i++) {
    const recipeData = DataGenerator.generateRecipe();
    const recipe = client.createRecipe(recipeData);
    recipes.push(recipe);
    sleep(Math.random() * 3 + 1); // 1-4 seconds think time
  }

  // 4. View all recipes
  client.getRecipes();
  sleep(CONFIG.thinkTime.min);

  // 5. View a specific recipe details
  if (recipes.length > 0) {
    client.getRecipe(recipes[0].id);
    sleep(CONFIG.thinkTime.min);
  }

  // 6. Create schedule for next week (7 days)
  const dateRange = DataGenerator.generateDateRange(7, 7); // Next week

  for (let i = 0; i < 7; i++) {
    const date = DataGenerator.generateDate(7 + i);
    const recipe = recipes[Math.floor(Math.random() * recipes.length)];
    const scheduleData = DataGenerator.generateScheduleEntry(recipe.id);

    client.upsertSchedule(date, scheduleData);
    sleep(1); // Short delay between schedule updates
  }

  // 7. View schedule
  client.getSchedule(dateRange.start, dateRange.end);
  sleep(CONFIG.thinkTime.min);

  // 8. Generate grocery list from scheduled recipes
  client.generateGroceryItems(dateRange.start, dateRange.end);
  sleep(CONFIG.thinkTime.min);

  // 9. View grocery items
  const groceryItems = client.getGroceryItems();
  sleep(CONFIG.thinkTime.min);

  // 10. Mark some items as completed
  if (groceryItems.length > 0) {
    const numToComplete = Math.min(3, groceryItems.length);
    for (let i = 0; i < numToComplete; i++) {
      const item = groceryItems[i];
      client.updateGroceryItem(item.id, {
        data: {
          name: item.name,
          quantity: item.quantity,
          aisle: item.aisle,
          unit: item.unit,
          status: 'completed'
        }
      });
      sleep(1);
    }
  }

  // 11. Add manual grocery item
  const manualItem = DataGenerator.generateGroceryItem();
  const createdItem = client.createGroceryItem(manualItem);
  sleep(CONFIG.thinkTime.min);

  // 12. Search for food items
  client.search('milk');
  sleep(CONFIG.thinkTime.min);

  // 13. Checkout completed items
  client.checkoutGroceryItems();
  sleep(CONFIG.thinkTime.min);

  // 14. View remaining grocery items
  client.getGroceryItems();
  sleep(CONFIG.thinkTime.min);

  // 15. Update a recipe (make it a favorite)
  if (recipes.length > 0) {
    const recipeToUpdate = recipes[0];
    const updatedData = DataGenerator.generateRecipe();
    updatedData.data.name = `Updated ${recipeToUpdate.name}`;
    updatedData.data.liked = true;

    client.updateRecipe(recipeToUpdate.id, updatedData);
    sleep(CONFIG.thinkTime.min);
  }

  // 16. Check invitations (even if empty)
  client.getInvitations();
  sleep(CONFIG.thinkTime.min);

  // // 17. Logout
  // AuthHelper.logout(token);
}
