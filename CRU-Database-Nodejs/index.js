// Main entry point of the application where the server and routing are configured.

// Import libraries to: create webserver, connect to MongoDB, import product model and routes
const express = require('express');
const mongoose = require('mongoose');
// Bring the function definition
const Product = require('./models/product.model.js');
const productRoute = require('./routes/product.route.js');

// Create an express application
const app = express();

// Configure middleware for JSON and URL encoding:
app.use(express.json()); // Enable JSON parsing for incoming requests
app.use(express.urlencoded({extended: false})); // Enable parsing URL-encoded form data

/*
Set up product routing endpoint to '/api/products' using product.route.js
Express modularizes route handling. The complete URL is determined by
where the router is mounted in the main application (index.js).
Using this definition, we will only use relative paths '/', '/:id' in
product.route.js
*/
app.use("/api/products", productRoute);

// Establish connection to MongoDB database (username and password not shared)
mongoose
    .connect(
        //'mongodb+srv://<username>:<db_password>@cluster0.emyfy.mongodb.net/?retryWrites=true&w=majority&appName=Cluster0'
        'mongodb+srv://<username>:<password>@cluster0.emyfy.mongodb.net/?retryWrites=true&w=majority&appName=Cluster0'
    )
    .then(() => {
        console.log('Connected to MongoDB database.');
        // Connect server to a port
        app.listen(3000, () => {
            console.log('Server is running on port 3000')
        })
    })
    .catch(() => {
        console.log('Not connected to MongoDB database.');
    });
