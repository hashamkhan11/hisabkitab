const express = require("express");
const router = express.Router();
const crypto = require("crypto");

router.post("/generateEasypaisaLink", (req, res) => {
  const { amount, email, mobileNo } = req.body;

  const storeId = "store123";           //  Replace with real value
  const merchantId = "MERCHANT123";     //  Replace with real value
  const returnUrl = "https://hisabkitab-b66b5.web.app/easypaisa_return.html";
  const secretKey = "easypaisaSecret";  // Replace with Easypaisa's HMAC key

  const orderRef = `EP-${Date.now()}`;
  const expiryDateTime = new Date(Date.now() + 60 * 60 * 1000).toISOString().replace(/[-:.TZ]/g, "").substring(0, 14);

  const hashString = `${merchantId}&${orderRef}&${amount}&${storeId}&${returnUrl}&${expiryDateTime}`;
  const secureHash = crypto.createHmac("sha256", secretKey).update(hashString).digest("hex").toUpperCase();

  const queryParams = new URLSearchParams({
    merchantId,
    storeId,
    orderRef,
    amount,
    mobileNo,
    email,
    postBackURL: returnUrl,
    expiryDateTime,
    secureHash
  });

  const hostedFormUrl = `https://hisabkitab-b66b5.web.app/easypaisa_payment_form.html?${queryParams.toString()}`;
  res.status(200).json({ paymentUrl: hostedFormUrl });
});

module.exports = router;
