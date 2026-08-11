const express = require("express");
const router = express.Router();
const Stripe = require("stripe");

const stripe = new Stripe("sk");

router.post("/createCheckoutSession", async (req, res) => {
  const { amount, email } = req.body;

  try {
    const session = await stripe.checkout.sessions.create({
      payment_method_types: ["card"],
      line_items: [
        {
          price_data: {
            currency: "usd",  
            product_data: {
              name: "Payment via Stripe",
            },
            unit_amount: Math.round(Number(amount) * 100), 
          },
          quantity: 1,
        },
      ],
      mode: "payment",
      customer_email: email,
      success_url: "https://hisabkitab-b66b5.web.app/stripe_success.html",
      cancel_url: "https://hisabkitab-b66b5.web.app/stripe_cancel.html",
    });

    res.status(200).json({ sessionId: session.id, checkoutUrl: session.url });
  } catch (err) {
    console.error("❌ Stripe Error:", err);
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
