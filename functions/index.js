const functions = require("firebase-functions");
const express = require("express");
const cors = require("cors");

// Import routes
const jazzcashRoutes = require("./jazzcash/jazzcash");
const easypaisaRoutes = require("./easypaisa/easypaisa");

const app = express();
app.use(cors({ origin: true }));
app.use(express.json());

// Mount payment routes
app.use("/jazzcash", jazzcashRoutes);
app.use("/easypaisa", easypaisaRoutes);
const stripeRoutes = require("./stripe/stripe");
app.use("/stripe", stripeRoutes);

exports.api = functions.https.onRequest(app);



