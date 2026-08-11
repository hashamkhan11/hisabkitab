const express = require("express");
const crypto = require("crypto");
const axios = require("axios");

const router = express.Router();

// JazzCash credentials
const merchantID = process.env.JAZZCASH_MERCHANT_ID;
const password = process.env.JAZZCASH_PASSWORD;
const integritySalt = process.env.JAZZCASH_INTEGRITY_SALT;
const baseURL = "https://payments.jazzcash.com.pk/CustomerPortal/transactionmanagement/merchantinquiry/";

router.post("/inquiry", async (req, res) => {
  try {
    const { orderRef } = req.body;

    if (!orderRef) {
      return res.status(400).json({ error: "Missing orderRef" });
    }

    const dateTime = new Date().toISOString().replace(/[-:.TZ]/g, "").slice(0, 14);

    const params = {
      pp_Version: "1.1",
      pp_TxnType: "MWALLET",
      pp_Language: "EN",
      pp_MerchantID: merchantID,
      pp_Password: password,
      pp_TxnRefNo: orderRef,
      pp_TxnDateTime: dateTime,
      pp_SecureHash: "",
    };

    const hashString = integritySalt + '&' +
      Object.values({ ...params, pp_SecureHash: undefined }).join('&');

    const secureHash = crypto.createHash('sha256').update(hashString).digest('hex').toUpperCase();
    params.pp_SecureHash = secureHash;

    const formData = new URLSearchParams(params);

    const response = await axios.post(baseURL, formData);

    return res.status(200).json({ response: response.data });
  } catch (error) {
    console.error("❌ Inquiry Error:", error);
    return res.status(500).json({ error: "Inquiry request failed" });
  }
});

module.exports = router;
