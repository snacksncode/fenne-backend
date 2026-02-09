import http from 'k6/http';
import { check } from 'k6';
import { CONFIG } from './config.js';
import { AuthHelper } from './auth.js';

/**
 * API client for Fenne Planner API
 * Wraps all API endpoints with proper authentication and validation
 */
export class ApiClient {
  constructor(token) {
    this.token = token;
  }

  // ========== Grocery Items ==========

  /**
   * Get all grocery items for user's family
   * @returns {Array} - Array of grocery items
   */
  getGroceryItems() {
    const res = http.get(
      `${CONFIG.baseUrl}/grocery_items`,
      { headers: AuthHelper.getHeaders(this.token) }
    );

    check(res, {
      'get grocery items successful': (r) => r.status === 200,
      'returns array': (r) => Array.isArray(r.json()),
    });

    return res.json();
  }

  /**
   * Get specific grocery item
   * @param {string|number} id - Grocery item ID
   * @returns {object} - Grocery item
   */
  getGroceryItem(id) {
    const res = http.get(
      `${CONFIG.baseUrl}/grocery_items/${id}`,
      { headers: AuthHelper.getHeaders(this.token) }
    );

    check(res, {
      'get grocery item successful': (r) => r.status === 200,
      'returns item': (r) => r.json('id') !== undefined,
    });

    return res.json();
  }

  /**
   * Create new grocery item
   * @param {object} data - Grocery item data (wrapped in {data: {...}})
   * @returns {object} - Created grocery item
   */
  createGroceryItem(data) {
    const res = http.post(
      `${CONFIG.baseUrl}/grocery_items`,
      JSON.stringify(data),
      { headers: AuthHelper.getHeaders(this.token) }
    );

    check(res, {
      'create grocery item successful': (r) => r.status === 201,
      'returns item': (r) => r.json('id') !== undefined,
    });

    return res.json();
  }

  /**
   * Update grocery item
   * @param {string|number} id - Grocery item ID
   * @param {object} data - Updated grocery item data
   * @returns {object} - Updated grocery item
   */
  updateGroceryItem(id, data) {
    const res = http.put(
      `${CONFIG.baseUrl}/grocery_items/${id}`,
      JSON.stringify(data),
      { headers: AuthHelper.getHeaders(this.token) }
    );

    check(res, {
      'update grocery item successful': (r) => r.status === 200,
    });

    return res.json();
  }

  /**
   * Delete grocery item
   * @param {string|number} id - Grocery item ID
   */
  deleteGroceryItem(id) {
    const res = http.del(
      `${CONFIG.baseUrl}/grocery_items/${id}`,
      null,
      { headers: AuthHelper.getHeaders(this.token) }
    );

    check(res, {
      'delete grocery item successful': (r) => r.status === 204 || r.status === 200,
    });
  }

  /**
   * Checkout (delete) all completed grocery items
   */
  checkoutGroceryItems() {
    const res = http.post(
      `${CONFIG.baseUrl}/grocery_items/checkout`,
      null,
      { headers: AuthHelper.getHeaders(this.token) }
    );

    check(res, {
      'checkout successful': (r) => r.status === 200 || r.status === 204,
    });
  }

  /**
   * Generate grocery list from scheduled recipes
   * @param {string} start - Start date (YYYY-MM-DD)
   * @param {string} end - End date (YYYY-MM-DD)
   * @returns {Array} - Generated grocery items
   */
  generateGroceryItems(start, end) {
    const res = http.post(
      `${CONFIG.baseUrl}/grocery_items/generate`,
      JSON.stringify({ start, end }),
      { headers: AuthHelper.getHeaders(this.token) }
    );

    check(res, {
      'generate grocery items successful': (r) => r.status === 200,
    });

    return res.json();
  }

  // ========== Recipes ==========

  /**
   * Get all recipes for user's family
   * @returns {Array} - Array of recipes
   */
  getRecipes() {
    const res = http.get(
      `${CONFIG.baseUrl}/recipes`,
      { headers: AuthHelper.getHeaders(this.token) }
    );

    check(res, {
      'get recipes successful': (r) => r.status === 200,
      'returns array': (r) => Array.isArray(r.json()),
    });

    return res.json();
  }

  /**
   * Get specific recipe with ingredients
   * @param {string|number} id - Recipe ID
   * @returns {object} - Recipe with ingredients
   */
  getRecipe(id) {
    const res = http.get(
      `${CONFIG.baseUrl}/recipes/${id}`,
      { headers: AuthHelper.getHeaders(this.token) }
    );

    check(res, {
      'get recipe successful': (r) => r.status === 200,
      'has ingredients': (r) => Array.isArray(r.json('ingredients')),
    });

    return res.json();
  }

  /**
   * Create new recipe
   * @param {object} data - Recipe data with ingredients (wrapped in {data: {...}})
   * @returns {object} - Created recipe
   */
  createRecipe(data) {
    const res = http.post(
      `${CONFIG.baseUrl}/recipes`,
      JSON.stringify(data),
      { headers: AuthHelper.getHeaders(this.token) }
    );

    check(res, {
      'create recipe successful': (r) => r.status === 200,
      'returns recipe': (r) => r.json('id') !== undefined,
      'has ingredients': (r) => Array.isArray(r.json('ingredients')),
    });

    return res.json();
  }

  /**
   * Update recipe
   * @param {string|number} id - Recipe ID
   * @param {object} data - Updated recipe data
   * @returns {object} - Updated recipe
   */
  updateRecipe(id, data) {
    const res = http.put(
      `${CONFIG.baseUrl}/recipes/${id}`,
      JSON.stringify(data),
      { headers: AuthHelper.getHeaders(this.token) }
    );

    check(res, {
      'update recipe successful': (r) => r.status === 200,
    });

    return res.json();
  }

  /**
   * Delete recipe
   * @param {string|number} id - Recipe ID
   */
  deleteRecipe(id) {
    const res = http.del(
      `${CONFIG.baseUrl}/recipes/${id}`,
      null,
      { headers: AuthHelper.getHeaders(this.token) }
    );

    check(res, {
      'delete recipe successful': (r) => r.status === 204 || r.status === 200,
    });
  }

  // ========== Schedule ==========

  /**
   * Get schedule for date range
   * @param {string} start - Start date (YYYY-MM-DD)
   * @param {string} end - End date (YYYY-MM-DD)
   * @returns {Array} - Array of schedule days
   */
  getSchedule(start, end) {
    const res = http.get(
      `${CONFIG.baseUrl}/schedule?start=${start}&end=${end}`,
      { headers: AuthHelper.getHeaders(this.token) }
    );

    check(res, {
      'get schedule successful': (r) => r.status === 200,
      'returns array': (r) => Array.isArray(r.json()),
    });

    return res.json();
  }

  /**
   * Create or update schedule for specific date
   * @param {string} date - Date (YYYY-MM-DD)
   * @param {object} data - Schedule data with meals
   * @returns {object} - Created/updated schedule day
   */
  upsertSchedule(date, data) {
    const res = http.put(
      `${CONFIG.baseUrl}/schedule/${date}`,
      JSON.stringify(data),
      { headers: AuthHelper.getHeaders(this.token) }
    );

    check(res, {
      'upsert schedule successful': (r) => r.status === 200,
    });

    return res.json();
  }

  // ========== Invitations ==========

  /**
   * Get family invitations (received and sent)
   * @returns {object} - { received: [], sent: [] }
   */
  getInvitations() {
    const res = http.get(
      `${CONFIG.baseUrl}/invitations`,
      { headers: AuthHelper.getHeaders(this.token) }
    );

    check(res, {
      'get invitations successful': (r) => r.status === 200,
      'has received': (r) => r.json('received') !== undefined,
      'has sent': (r) => r.json('sent') !== undefined,
    });

    return res.json();
  }

  /**
   * Send family invitation to email
   * @param {string} email - Email to invite
   * @returns {object} - Created invitation
   */
  sendInvitation(email) {
    const res = http.post(
      `${CONFIG.baseUrl}/invitations`,
      JSON.stringify({ email }),
      { headers: AuthHelper.getHeaders(this.token) }
    );

    check(res, {
      'send invitation successful': (r) => r.status === 200,
    });

    return res.json();
  }

  /**
   * Accept family invitation
   * @param {string|number} invitationId - Invitation ID
   */
  acceptInvitation(invitationId) {
    const res = http.post(
      `${CONFIG.baseUrl}/invitations/${invitationId}/accept`,
      null,
      { headers: AuthHelper.getHeaders(this.token) }
    );

    check(res, {
      'accept invitation successful': (r) => r.status === 200,
    });

    return res.json();
  }

  /**
   * Decline family invitation
   * @param {string|number} invitationId - Invitation ID
   */
  declineInvitation(invitationId) {
    const res = http.post(
      `${CONFIG.baseUrl}/invitations/${invitationId}/decline`,
      null,
      { headers: AuthHelper.getHeaders(this.token) }
    );

    check(res, {
      'decline invitation successful': (r) => r.status === 200,
    });
  }

  /**
   * Cancel sent invitation
   * @param {string|number} invitationId - Invitation ID
   */
  cancelInvitation(invitationId) {
    const res = http.del(
      `${CONFIG.baseUrl}/invitations/${invitationId}`,
      null,
      { headers: AuthHelper.getHeaders(this.token) }
    );

    check(res, {
      'cancel invitation successful': (r) => r.status === 204 || r.status === 200,
    });
  }

  /**
   * Leave current family
   */
  leaveFamily() {
    const res = http.post(
      `${CONFIG.baseUrl}/leave_family`,
      null,
      { headers: AuthHelper.getHeaders(this.token) }
    );

    check(res, {
      'leave family successful': (r) => r.status === 200,
    });
  }

  // ========== Search ==========

  /**
   * Search/autocomplete for food items
   * @param {string} query - Search query
   * @returns {Array} - Array of matching food items
   */
  search(query) {
    const res = http.get(
      `${CONFIG.baseUrl}/search?q=${encodeURIComponent(query)}`,
      { headers: AuthHelper.getHeaders(this.token) }
    );

    check(res, {
      'search successful': (r) => r.status === 200,
      'returns array': (r) => Array.isArray(r.json()),
    });

    return res.json();
  }

  /**
   * Delete custom food item from search results
   * @param {string|number} id - Food item ID
   */
  deleteSearchItem(id) {
    const res = http.del(
      `${CONFIG.baseUrl}/search/${id}`,
      null,
      { headers: AuthHelper.getHeaders(this.token) }
    );

    check(res, {
      'delete search item successful': (r) => r.status === 204 || r.status === 200,
    });
  }

  // ========== Health Check ==========

  /**
   * Check API health (public endpoint)
   * @returns {boolean} - True if API is healthy
   */
  static healthCheck() {
    const res = http.get(`${CONFIG.baseUrl}/up`);

    check(res, {
      'health check successful': (r) => r.status === 200,
    });

    return res.status === 200;
  }
}
