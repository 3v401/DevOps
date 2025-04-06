/*
API controllers:
Contains the business logic for product operations. Here is where
the program interacts with the database.
*/

const Product = require('../models/product.model'); // Import product model

const getProducts = async (req, res) => {
    try {
        const products = await Product.find({});
        // return all products in JSON response:
        res.status(200).json(products);
    } catch (error) {
        res.status(500).json({message: error.message});
    }
};

const getProduct = async (req, res) => {
    try {
        const { id } = req.params;
        const product = await Product.findById(id);
        // return specific product (by ID) in JSON response:
        res.status(200).json(product);
    } catch (error) {
        res.status(500).json({ message: error.message });
    }
};

const createProduct = async (req, res) => {
    try {
        const product = await Product.create(req.body);
        // return the created product in JSON format
        res.status(200).json(product);
    } catch (error) {
        res.status(500).json({ message: error.message });
    }
};

const updateProduct = async (req, res) => {
    try {
        const { id } = req.params;
        const product = await Product.findByIdAndUpdate(id, req.body);

        if (!product) {
            return res.status(404).json({ message: 'Product not found.' });
        }
        const updatedProduct = await Product.findById(id);
        // return updated product in JSON format
        res.status(200).json(updatedProduct);

    } catch (error) {
        error.status(500).json({ message: error.message });
    }
};

const deleteProduct = async (req, res) => {
    try {
        const { id } = req.params;
        const product = await Product.findByIdAndDelete(id);

        if (!product) {
            return res.status(404).json({ message: 'Product not found.' });
        }
        // return 'Product deleted'
        res.status(200).json({ message: 'Product deleted.' });

    } catch (error) {
        res.status(500).json({ message: error.message });
    }
};

// Export all functions so routes (product.route.js) can use them
module.exports = {
    getProducts,
    getProduct,
    createProduct,
    updateProduct,
    deleteProduct
};