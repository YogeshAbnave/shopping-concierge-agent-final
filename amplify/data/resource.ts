import { type ClientSchema, a, defineData } from '@aws-amplify/backend'

const schema = a.schema({
  // UserProfile model - for user information and preferences
  UserProfile: a.model({
    id: a.id().required(),           // AppSync auto-generated UUID (Primary Key)
    user_id: a.string().required(),  // User identifier (attribute)
    email: a.string(),               // User email
    name: a.string(),                // User name
    preferences: a.string(),         // User preferences (JSON string)
    created_at: a.string(),          // Creation timestamp
    updated_at: a.string(),          // Last update timestamp
  })
  .authorization((allow: any) => [allow.authenticated()])
  .secondaryIndexes((index: any) => [
    index('user_id')  // GSI for fast user queries
  ]),

  // Wishlist model - for cart functionality with multiple items per user
  Wishlist: a.model({
    id: a.id().required(),           // AppSync auto-generated UUID (Primary Key)
    user_id: a.string().required(),  // User identifier (attribute)
    asin: a.string().required(),     // Amazon Standard Identification Number
    title: a.string().required(),    // Product title
    price: a.string().required(),    // Product price
    reviews: a.string(),             // Product review score
    url: a.string(),                 // Product URL
  })
  .authorization((allow: any) => [allow.authenticated()])
  .secondaryIndexes((index: any) => [
    index('user_id')  // GSI for fast user queries
  ]),

  // Bookings model - for purchase history (products only)
  Bookings: a.model({
    id: a.id().required(),           // AppSync auto-generated UUID
    user_id: a.string().required(),  // User identifier
    order_id: a.string().required(), // Order ID from purchase
    item_type: a.string().required(),// 'product' (shopping-only)
    title: a.string().required(),    // Item title
    price: a.string().required(),    // Price paid
    purchase_date: a.string(),       // Purchase date (ISO string)
    asin: a.string(),                // Amazon Standard Identification Number
    url: a.string(),                 // Product URL
  })
  .authorization((allow: any) => [allow.authenticated()])
  .secondaryIndexes((index: any) => [
    index('user_id')  // GSI for fast user queries
  ]),
})

export type Schema = ClientSchema<typeof schema>

export const data = defineData({
  schema,
  authorizationModes: {
    defaultAuthorizationMode: 'userPool',
  },
})
