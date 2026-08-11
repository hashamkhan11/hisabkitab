const express = require("express");
const router = express.Router();
const crypto = require("crypto");

router.post("/generateJazzCashLink", (req, res) => {
  const { amount, email, mobileNo } = req.body;

  const merchantId = process.env.JAZZCASH_MERCHANT_ID;
  const password = process.env.JAZZCASH_PASSWORD;
  const integritySalt = process.env.JAZZCASH_INTEGRITY_SALT;
  const returnURL = "https://hisabkitab-b66b5.web.app/return.html";

  const orderRef = `JC-${Date.now()}`;
  const amountInPaisa = (Number(amount) * 100).toFixed(0);
  const dateTime = new Date().toISOString().replace(/[-:.TZ]/g, "").substring(0, 14);
  const expiry = new Date(Date.now() + 60 * 60 * 1000).toISOString().replace(/[-:.TZ]/g, "").substring(0, 14);

  const postData = {
    pp_Version: "1.1",
    pp_TxnType: "MWALLET",
    pp_Language: "EN",
    pp_MerchantID: merchantId,
    pp_Password: password,
    pp_TxnRefNo: orderRef,
    pp_Amount: amountInPaisa,
    pp_TxnDateTime: dateTime,
    pp_BillReference: "Ref123",
    pp_Description: "JazzCash Payment",
    pp_TxnExpiryDateTime: expiry,
    pp_ReturnURL: returnURL,
    pp_TxnCurrency: "PKR",
    pp_SecureHash: "",
    ppmpf_1: email,
    ppmpf_2: mobileNo,
    ppmpf_3: "", ppmpf_4: "", ppmpf_5: ""
  };

  const hashString = integritySalt + "&" +
    postData.pp_Amount + "&" +
    postData.pp_BillReference + "&" +
    postData.pp_Description + "&" +
    postData.pp_Language + "&" +
    postData.pp_MerchantID + "&" +
    postData.pp_Password + "&" +
    postData.pp_ReturnURL + "&" +
    postData.pp_TxnCurrency + "&" +
    postData.pp_TxnDateTime + "&" +
    postData.pp_TxnExpiryDateTime + "&" +
    postData.pp_TxnRefNo + "&" +
    postData.pp_TxnType + "&" +
    postData.pp_Version + "&" +
    postData.ppmpf_1 + "&" +
    postData.ppmpf_2 + "&" +
    postData.ppmpf_3 + "&" +
    postData.ppmpf_4 + "&" +
    postData.ppmpf_5;

  const secureHash = crypto.createHmac("sha256", integritySalt)
    .update(hashString)
    .digest("hex")
    .toUpperCase();

  postData.pp_SecureHash = secureHash;

  const hostedFormUrl = "https://hisabkitab-b66b5.web.app/payment_form.html?" + new URLSearchParams(postData).toString();
  res.status(200).json({ paymentUrl: hostedFormUrl });
});

module.exports = router;
