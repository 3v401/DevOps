// API routes:

const express = require("express");
const router = express.Router(); // Create router object
const Product = require('../models/product.model.js');
// Import controller functions:
const {getProducts, getProduct, createProduct, updateProduct, deleteProduct} = require('../controllers/product.controller.js')

/*
Each route maps a specific HTTP method (GET, POST...) and URL
to a controller function.
*/
router.get('/', getProducts); // GET /api/products -> Get list of products
router.get('/:id', getProduct); // GET /api/products/:id -> Get one product
router.post('/', createProduct); // POST /api/products -> Create a product
router.put('/:id', updateProduct); // PUT /api/products/:id -> Update a product
router.delete('/:id', deleteProduct); // DELETE /api/products/:id -> Delete a product

// Export the router for index.js to use it:
module.exports = router;