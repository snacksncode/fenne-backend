import http from 'k6/http';
import { check } from 'k6';
import { CONFIG } from './config.js';

/**
 * Authentication helper class for the Fenne Planner API
 * Handles signup, login, logout, and token management
 */
export class AuthHelper {
  /**
   * Create a new user via signup
   * @param {string} email - User email (will be downcased by API)
   * @param {string} password - User password
   * @param {string} name - User full name
   * @returns {object} - { token: string, email: string }
   */
  static signup(email, password, name) {
    const res = http.post(
      `${CONFIG.baseUrl}/signup`,
      JSON.stringify({ email, password, name }),
      { headers: { 'Content-Type': 'application/json' } }
    );

    check(res, {
      'signup successful': (r) => r.status === 200,
      'signup returns token': (r) => r.json('session_token') !== undefined,
    });

    return {
      token: res.json('session_token'),
      email: email,
    };
  }

  /**
   * Login existing user
   * @param {string} email - User email
   * @param {string} password - User password
   * @returns {string} - Session token (64-character hex string)
   */
  static login(email, password) {
    const res = http.post(
      `${CONFIG.baseUrl}/login`,
      JSON.stringify({ email, password }),
      { headers: { 'Content-Type': 'application/json' } }
    );

    check(res, {
      'login successful': (r) => r.status === 200,
      'login returns token': (r) => r.json('session_token') !== undefined,
    });

    return res.json('session_token');
  }

  /**
   * Create anonymous guest user
   * @returns {string} - Session token
   */
  static createGuest() {
    const res = http.post(
      `${CONFIG.baseUrl}/guest`,
      null,
      { headers: { 'Content-Type': 'application/json' } }
    );

    check(res, {
      'guest creation successful': (r) => r.status === 200,
      'guest returns token': (r) => r.json('session_token') !== undefined,
    });

    return res.json('session_token');
  }

  /**
   * Get current user info
   * @param {string} token - Session token
   * @returns {object} - { user: {...}, family: {...} }
   */
  static getMe(token) {
    const res = http.get(
      `${CONFIG.baseUrl}/me`,
      { headers: { 'Authorization': `Bearer ${token}` } }
    );

    check(res, {
      'get me successful': (r) => r.status === 200,
      'returns user': (r) => r.json('user') !== undefined,
      'returns family': (r) => r.json('family') !== undefined,
    });

    return res.json();
  }

  /**
   * Change user password
   * @param {string} token - Session token
   * @param {string} currentPassword - Current password
   * @param {string} newPassword - New password
   */
  static changePassword(token, currentPassword, newPassword) {
    const res = http.post(
      `${CONFIG.baseUrl}/change_password`,
      JSON.stringify({ current_password: currentPassword, new_password: newPassword }),
      { headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      }}
    );

    check(res, {
      'change password successful': (r) => r.status === 200,
    });
  }

  /**
   * Logout (destroy session token)
   * @param {string} token - Session token
   */
  static logout(token) {
    const res = http.post(
      `${CONFIG.baseUrl}/logout`,
      null,
      { headers: { 'Authorization': `Bearer ${token}` } }
    );

    check(res, {
      'logout successful': (r) => r.status === 200,
    });
  }

  /**
   * Get authorization headers for authenticated requests
   * @param {string} token - Session token
   * @returns {object} - Headers object with Authorization and Content-Type
   */
  static getHeaders(token) {
    return {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json',
    };
  }
}
