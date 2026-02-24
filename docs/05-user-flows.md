# User Flows

**Project:** Artisanal Lane -- Curated Craft Marketplace
**Version:** 1.0

---

## Table of Contents

1. [Buyer Onboarding](#1-buyer-onboarding)
2. [Buyer Purchase Flow](#2-buyer-purchase-flow)
3. [Vendor Application Flow](#3-vendor-application-flow)
4. [Vendor Shop Setup](#4-vendor-shop-setup)
5. [Vendor Product Management](#5-vendor-product-management)
6. [Vendor Order Fulfillment](#6-vendor-order-fulfillment)
7. [Admin Vendor Approval](#7-admin-vendor-approval)
8. [Admin Dispute Resolution](#8-admin-dispute-resolution)

---

## 1. Buyer Onboarding

```mermaid
flowchart TD
    Start([Open App]) --> HasAccount{Has account?}
    HasAccount -->|No| SignUp[Sign Up Screen]
    HasAccount -->|Yes| Login[Login Screen]

    SignUp --> Method{Method?}
    Method -->|Email| EnterEmail[Enter email + password]
    Method -->|Google| GoogleOAuth[Google OAuth flow]
    Method -->|Apple| AppleSignIn[Apple Sign-In flow]

    EnterEmail --> VerifyEmail[Verification email sent]
    VerifyEmail --> ClickLink[User clicks verification link]
    ClickLink --> ProfileSetup[Set display name + avatar]

    GoogleOAuth --> ProfileSetup
    AppleSignIn --> ProfileSetup

    ProfileSetup --> HomeFeed[Home Feed]

    Login --> LoginMethod{Method?}
    LoginMethod -->|Email| EnterCreds[Enter email + password]
    LoginMethod -->|Google| GoogleOAuth2[Google OAuth flow]
    LoginMethod -->|Apple| AppleSignIn2[Apple Sign-In flow]

    EnterCreds --> HomeFeed
    GoogleOAuth2 --> HomeFeed
    AppleSignIn2 --> HomeFeed
```

### Flow Description

1. User opens the app for the first time and sees the onboarding / welcome screen.
2. User chooses to sign up via email, Google, or Apple.
3. For email sign-up, a verification email is sent; user must verify before full access.
4. After authentication, user sets up their basic profile (display name and optional avatar).
5. User is directed to the home feed and can begin browsing.

---

## 2. Buyer Purchase Flow

```mermaid
flowchart TD
    Browse([Browse Marketplace]) --> ViewType{View type?}

    ViewType -->|Items View| ItemsFeed[Browse products by category]
    ViewType -->|Shops View| ShopsList[Browse vendor directory]

    ItemsFeed --> Search[Search / Filter / Sort]
    Search --> ProductCard[Tap product card]
    ShopsList --> ShopProfile[View shop profile]
    ShopProfile --> ShopProducts[Browse shop products]
    ShopProducts --> ProductCard

    ProductCard --> ProductDetail[Product Detail Page]
    ProductDetail --> AddFav{Add to favourites?}
    AddFav -->|Yes| SaveFav[Save to favourites]
    AddFav -->|No| AddCart{Add to cart?}
    SaveFav --> AddCart

    AddCart -->|Yes| SelectQty[Select quantity]
    AddCart -->|No| Browse

    SelectQty --> CartAdded[Item added to cart]
    CartAdded --> ContinueShopping{Continue shopping?}
    ContinueShopping -->|Yes| Browse
    ContinueShopping -->|No| ViewCart[View Cart]

    ViewCart --> ReviewItems[Review items and quantities]
    ReviewItems --> Checkout[Proceed to Checkout]

    Checkout --> SelectShipping[Select shipping method]
    SelectShipping --> ShippingType{Type?}
    ShippingType -->|Courier Guy| EnterAddress[Enter delivery address]
    ShippingType -->|Pargo| SelectPargo[Select Pargo pickup point]
    ShippingType -->|PAXI| SelectPAXI[Select PAXI point]
    ShippingType -->|Market Pickup| ConfirmPickup[Confirm pickup arrangement]

    EnterAddress --> OrderSummary[Review order summary]
    SelectPargo --> OrderSummary
    SelectPAXI --> OrderSummary
    ConfirmPickup --> OrderSummary

    OrderSummary --> PayNow[Tap Pay Now]
    PayNow --> PayFast[Redirect to PayFast]
    PayFast --> PaymentResult{Payment result?}

    PaymentResult -->|Success| Confirmation[Order Confirmation Screen]
    PaymentResult -->|Failed| PaymentError[Payment Error - Retry]
    PaymentError --> PayNow

    Confirmation --> TrackOrder[Track Order Status]
    TrackOrder --> OrderShipped[Vendor ships order]
    OrderShipped --> ReceiveOrder[Receive order]
    ReceiveOrder --> ConfirmReceipt{Confirm receipt?}

    ConfirmReceipt -->|Yes| FundsReleased[Escrow funds released to vendor]
    ConfirmReceipt -->|Dispute| RaiseDispute[Raise a dispute]
    RaiseDispute --> AdminReview[Admin reviews dispute]
    FundsReleased --> Done([Order Complete])
    AdminReview --> Resolution[Admin resolves dispute]
    Resolution --> Done
```

### Flow Description

1. Buyer browses the marketplace via the Items view (category-based) or Shops view (vendor-based).
2. Buyer can search, filter by category/price, and sort results.
3. Buyer taps a product to view its detail page (images, description, price, vendor info).
4. Buyer can add the item to favourites or add it to their cart.
5. When ready, buyer views their cart, reviews items, and proceeds to checkout.
6. Buyer selects a shipping method (Courier Guy, Pargo, PAXI, or Market Pickup) and enters any required delivery details.
7. Buyer reviews the order summary and initiates payment via PayFast.
8. On successful payment, an order confirmation is shown with a summary and order number.
9. Buyer can track the order status as it progresses through paid, shipped, and delivered.
10. Upon receiving the item, buyer confirms receipt, which releases escrow funds to the vendor.
11. If there is an issue, buyer can raise a dispute for admin resolution.

---

## 3. Vendor Application Flow

```mermaid
flowchart TD
    Start([Receive Invite Code]) --> HasAccount{Has account?}
    HasAccount -->|No| SignUp[Sign up as buyer first]
    HasAccount -->|Yes| GoToApply[Go to Vendor Application]
    SignUp --> GoToApply

    GoToApply --> EnterCode[Enter invite code]
    EnterCode --> ValidCode{Code valid?}
    ValidCode -->|No| InvalidCode[Error: Invalid or used code]
    InvalidCode --> EnterCode
    ValidCode -->|Yes| AppForm[Fill application form]

    AppForm --> EnterDetails["Enter: business name,
        motivation, portfolio URL,
        location"]
    EnterDetails --> Submit[Submit application]
    Submit --> Pending[Application status: PENDING]

    Pending --> AdminAction{Admin decision?}
    AdminAction -->|Approved| Approved[Status: APPROVED]
    AdminAction -->|Rejected| Rejected[Status: REJECTED]

    Approved --> RoleUpdate[Profile role updated to vendor]
    RoleUpdate --> ShopCreated[Empty shop profile created]
    ShopCreated --> SetupShop([Proceed to Shop Setup])

    Rejected --> Notification[Rejection notification]
    Notification --> EndRejected([Cannot apply again])
```

### Flow Description

1. An existing artisan receives an invite code from the Artisanal Lane team or another vendor.
2. They must have an existing buyer account (or sign up for one).
3. In the app, they navigate to "Become a Vendor" and enter their invite code.
4. If the code is valid and unused, they fill out the application form with their business details.
5. The application is submitted and enters a "pending" state.
6. An admin reviews the application and either approves or rejects it.
7. On approval, the user's role is upgraded to "vendor" and an empty shop is created for them.
8. On rejection, the user is notified and the invite code remains consumed.

---

## 4. Vendor Shop Setup

```mermaid
flowchart TD
    Start([Application Approved]) --> ShopProfile[Shop Profile Screen]

    ShopProfile --> SetName[Enter shop name]
    SetName --> SetSlug[Auto-generate URL slug]
    SetSlug --> UploadLogo[Upload shop logo]
    UploadLogo --> UploadCover[Upload cover image]
    UploadCover --> WriteBio[Write shop bio]
    WriteBio --> WriteStory[Write brand story]
    WriteStory --> Preview[Preview shop]
    Preview --> Satisfied{Happy with shop?}
    Satisfied -->|No| EditDetails[Edit details]
    EditDetails --> Preview
    Satisfied -->|Yes| Activate[Activate shop]
    Activate --> ShopLive([Shop is live on marketplace])
```

### Flow Description

1. After vendor application approval, the vendor is taken to their shop profile setup.
2. They enter their shop name (URL slug is auto-generated).
3. They upload a logo and cover image for branding.
4. They write a short bio and a longer brand story.
5. They preview how their shop will look to buyers.
6. Once satisfied, they activate the shop and it becomes visible on the marketplace.

---

## 5. Vendor Product Management

```mermaid
flowchart TD
    Start([Vendor Dashboard]) --> Products[My Products]
    Products --> Action{Action?}

    Action -->|Add new| CreateProduct[Create Product]
    Action -->|Edit existing| SelectProduct[Select product]
    Action -->|View stats| ViewStats[View product performance]

    CreateProduct --> UploadImages[Upload product images]
    UploadImages --> EnterTitle[Enter title]
    EnterTitle --> EnterDesc[Enter description]
    EnterDesc --> SetCategory[Select category]
    SetCategory --> SetPrice[Set price]
    SetPrice --> SetComparePrice{Set compare-at price?}
    SetComparePrice -->|Yes| EnterCompare[Enter compare-at price]
    SetComparePrice -->|No| SetStock[Set stock quantity]
    EnterCompare --> SetStock
    SetStock --> PreviewProduct[Preview product]
    PreviewProduct --> PublishChoice{Publish now?}
    PublishChoice -->|Yes| PublishProduct[Publish product]
    PublishChoice -->|Save draft| SaveDraft[Save as unpublished]
    PublishProduct --> ProductLive([Product live on marketplace])
    SaveDraft --> Products

    SelectProduct --> EditProduct[Edit Product Screen]
    EditProduct --> EditFields[Modify fields]
    EditFields --> SaveChanges[Save changes]
    SaveChanges --> Products

    EditProduct --> UnpublishOption{Unpublish?}
    UnpublishOption -->|Yes| Unpublish[Set is_published = false]
    Unpublish --> Products
```

### Flow Description

1. From the vendor dashboard, the vendor navigates to "My Products."
2. To add a new product, they upload images, enter title, description, category, pricing, and stock.
3. They can preview the product as buyers will see it.
4. They choose to publish immediately or save as a draft.
5. Existing products can be edited (all fields) or unpublished.
6. Stock quantities are managed manually by the vendor.

---

## 6. Vendor Order Fulfillment

```mermaid
flowchart TD
    Start([New Order Notification]) --> ViewOrder[View Order Details]

    ViewOrder --> OrderInfo["See: buyer info, items,
        shipping method, address"]
    OrderInfo --> Prepare[Prepare shipment]
    Prepare --> ShipMethod{Shipping method?}

    ShipMethod -->|Courier Guy| PackCourier[Package for courier collection]
    ShipMethod -->|Pargo| PackPargo[Drop off at Pargo point]
    ShipMethod -->|PAXI| PackPAXI[Drop off at PEP/PAXI point]
    ShipMethod -->|Market Pickup| ArrangePickup[Arrange pickup with buyer]

    PackCourier --> EnterTracking[Enter tracking number]
    PackPargo --> EnterTracking
    PackPAXI --> EnterTracking
    ArrangePickup --> MarkReady[Mark as ready for collection]

    EnterTracking --> MarkShipped[Mark order as SHIPPED]
    MarkReady --> MarkShipped

    MarkShipped --> BuyerNotified[Buyer receives notification]
    BuyerNotified --> WaitDelivery[Wait for delivery]
    WaitDelivery --> BuyerConfirms{Buyer confirms receipt?}

    BuyerConfirms -->|Yes| EscrowReleased[Funds released to vendor]
    BuyerConfirms -->|Auto after 14 days| EscrowReleased
    BuyerConfirms -->|Dispute| DisputeOpen[Dispute opened]
    DisputeOpen --> AdminHandles[Admin resolves]
    AdminHandles --> Resolution{Resolution?}
    Resolution -->|Release| EscrowReleased
    Resolution -->|Refund| FundsRefunded[Funds refunded to buyer]

    EscrowReleased --> EarningsUpdated([Earnings dashboard updated])
    FundsRefunded --> EndRefund([Vendor notified of refund])
```

### Flow Description

1. Vendor receives a push notification when a new order is placed for their shop.
2. Vendor views the order details: items, quantities, buyer's selected shipping method, and address.
3. Vendor prepares the shipment according to the selected logistics provider.
4. Vendor enters the tracking number (if applicable) and marks the order as "Shipped."
5. Buyer is notified of shipment.
6. When the buyer confirms receipt (or after 14 days auto-release), escrow funds are released to the vendor.
7. If a dispute is raised, the admin resolves it and funds are either released or refunded.
8. Vendor's earnings dashboard is updated accordingly.

---

## 7. Admin Vendor Approval

```mermaid
flowchart TD
    Start([Admin Dashboard]) --> AppList[Vendor Applications List]
    AppList --> Filter[Filter by status: pending]
    Filter --> SelectApp[Select application]
    SelectApp --> ReviewDetail["Review: business name,
        motivation, portfolio,
        location, invite code"]

    ReviewDetail --> Decision{Decision?}
    Decision -->|Approve| Approve[Approve application]
    Decision -->|Reject| RejectReason[Enter rejection reason]
    Decision -->|Need more info| RequestInfo[Contact applicant]

    Approve --> UpdateRole[Set user role to vendor]
    UpdateRole --> CreateShop[Create empty shop record]
    CreateShop --> NotifyVendor[Send approval notification]
    NotifyVendor --> Done([Application processed])

    RejectReason --> UpdateRejected[Set status to rejected]
    UpdateRejected --> NotifyRejection[Send rejection notification]
    NotifyRejection --> Done

    RequestInfo --> WaitResponse[Wait for response]
    WaitResponse --> ReviewDetail
```

### Flow Description

1. Admin opens the vendor applications section of the admin dashboard.
2. Admin filters by "pending" status to see new applications.
3. Admin selects an application and reviews the details: business name, motivation, portfolio link, location, and the invite code used.
4. Admin makes a decision:
   - **Approve:** The user's role is upgraded to "vendor," an empty shop is created, and a notification is sent.
   - **Reject:** Admin enters a reason, the status is updated, and a notification is sent.
   - **Need more info:** Admin contacts the applicant for clarification before deciding.

---

## 8. Admin Dispute Resolution

```mermaid
flowchart TD
    Start([Admin Dashboard]) --> DisputeList[Open Disputes List]
    DisputeList --> SelectDispute[Select dispute]
    SelectDispute --> ReviewDispute["Review: order details,
        buyer complaint, product listing,
        delivery tracking"]

    ReviewDispute --> Investigate[Investigate further if needed]
    Investigate --> ContactParties{Contact parties?}
    ContactParties -->|Yes| ContactBuyer[Contact buyer for details]
    ContactParties -->|Yes| ContactVendor[Contact vendor for details]
    ContactParties -->|No| MakeDecision[Make decision]
    ContactBuyer --> MakeDecision
    ContactVendor --> MakeDecision

    MakeDecision --> Decision{Decision?}
    Decision -->|Favour buyer| Refund[Process refund to buyer]
    Decision -->|Favour vendor| Release[Release escrow to vendor]
    Decision -->|Partial| PartialRefund[Partial refund + partial release]

    Refund --> UpdateEscrow1[Update escrow: refunded]
    Release --> UpdateEscrow2[Update escrow: released]
    PartialRefund --> UpdateEscrow3[Update escrow records]

    UpdateEscrow1 --> UpdateOrder1[Update order: refunded]
    UpdateEscrow2 --> UpdateOrder2[Update order: delivered]
    UpdateEscrow3 --> UpdateOrder3[Update order status]

    UpdateOrder1 --> CloseDispute[Close dispute with resolution]
    UpdateOrder2 --> CloseDispute
    UpdateOrder3 --> CloseDispute

    CloseDispute --> NotifyParties[Notify both buyer and vendor]
    NotifyParties --> Done([Dispute resolved])
```

### Flow Description

1. Admin opens the disputes section of the admin dashboard.
2. Admin reviews the open dispute, including the order details, buyer's complaint, original product listing, and delivery tracking information.
3. Admin may contact the buyer and/or vendor for additional information.
4. Admin makes a resolution decision:
   - **Favour buyer:** Full refund to the buyer; escrow status updated to "refunded."
   - **Favour vendor:** Funds released to vendor; escrow status updated to "released."
   - **Partial resolution:** A partial refund to the buyer and partial release to the vendor.
5. The dispute is closed with a written resolution, the order status is updated, and both parties are notified.
