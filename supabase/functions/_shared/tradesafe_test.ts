import { assertEquals } from "jsr:@std/assert@1";

import {
  buildTokenInput,
  buildTradeSafeTransactionInput,
} from "./tradesafe.ts";

Deno.test("seller TradeSafe token input includes bank details and immediate payout settings", () => {
  const input = buildTokenInput({
    displayName: "Vendor Example",
    email: "vendor@example.com",
    mobile: "+27123456789",
    idNumber: "8001015009087",
    bankAccount: {
      bank: "FNB",
      accountNumber: "1234567890",
      accountType: "CHEQUE",
    },
    payoutSettings: {
      interval: "IMMEDIATE",
      refund: "IMMEDIATE",
    },
  });

  assertEquals(input.bankAccount, {
    bank: "FNB",
    accountNumber: "1234567890",
    accountType: "CHEQUE",
  });
  assertEquals(input.settings, {
    payout: {
      interval: "IMMEDIATE",
      refund: "IMMEDIATE",
    },
  });
});

Deno.test("TradeSafe checkout splits the integration fee between buyer and seller", () => {
  const input = buildTradeSafeTransactionInput({
    reference: "order-1",
    title: "Artisan Lane order",
    description: "Handmade item",
    buyerTokenId: "buyer-token",
    sellerTokenId: "seller-token",
    amount: 250,
  });

  assertEquals(input.feeAllocation, "BUYER_SELLER");
});
