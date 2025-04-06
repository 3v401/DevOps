/*
API model:
Let's define the schema for the Product collection in MongoDB.
*/

const mongoose = require('mongoose');

const ProductSchema = mongoose.Schema(
    {
        Model_name: { type: String, required: [true, "Please, enter parameter 1"] },
        Price: { type: Number, required: [true, 'Please, enter parameter 2'] },
        Returned: { type: String, required: true, default: 0 },
        Status: { type: String, required: false },
    },
    {
        // When it is created and when it is updated.
        timestamps: true
    }
);

// Create the 'Product' model, linking it to the 'products' collection in MongoDB
const Product = mongoose.model('Product', ProductSchema)
// Export the function Product to use in the future
module.exports = Product;