# Documentation API - Origna GTA

**Version:** 1.0  
**Date:** 3 février 2026  
**Base URL:** `https://us-central1-origna-gta.cloudfunctions.net`

---

## Table des Matières

1. [Authentification](#authentification)
2. [Gestion des Paiements (Stripe)](#gestion-des-paiements-stripe)
3. [Gestion des Paiements (Airwallex)](#gestion-des-paiements-airwallex)
4. [Gestion des Produits](#gestion-des-produits)
5. [Gestion des Commandes](#gestion-des-commandes)
6. [Chat et Communications](#chat-et-communications)
7. [Gestion des Adresses](#gestion-des-adresses)
8. [Produits Numériques et Licences](#produits-numériques-et-licences)
9. [Administration](#administration)
10. [Tâches Planifiées (Cron)](#tâches-planifiées-cron)
11. [Codes d'Erreur](#codes-derreur)

---

## Authentification

Tous les endpoints (sauf les webhooks) nécessitent une authentification Firebase Auth. Le token doit être inclus dans les en-têtes de la requête.

### En-têtes Requis

```http
Content-Type: application/json
```

---

## Gestion des Paiements (Stripe)

### 1. Créer une Session de Paiement

**Endpoint:** `create_checkout_session`  
**Méthode:** `POST` (Callable Function)  
**Authentification:** ✅ Requise  
**Rate Limiting:** 5 requêtes/minute par utilisateur

#### Paramètres

| Paramètre | Type | Requis | Description |
|-----------|------|--------|-------------|
| `items` | Array | ✅ | Liste des produits avec `productId`, `quantity`, `price`, `name`, `imageUrl`, `sellerId` |
| `shippingAddress` | Object | ✅ | Adresse de livraison: `street`, `city`, `province`, `postalCode`, `country` |
| `subtotal` | Number | ✅ | Sous-total calculé côté client (vérifié côté serveur) |
| `userId` | String | ✅ | ID de l'utilisateur Firebase |

#### Exemple de Requête

```json
{
  "items": [
    {
      "productId": "prod_123",
      "quantity": 2,
      "price": 29.99,
      "name": "T-Shirt",
      "imageUrl": "https://cdn.origna.ca/products/tshirt.jpg",
      "sellerId": "seller_456"
    }
  ],
  "shippingAddress": {
    "street": "123 Rue Principale",
    "city": "Montréal",
    "province": "QC",
    "postalCode": "H2X 1Y2",
    "country": "CA"
  },
  "subtotal": 59.98
}
```

#### Réponse Réussie (200)

```json
{
  "success": true,
  "sessionId": "cs_test_abc123",
  "orderId": "order_xyz789"
}
```

#### Erreurs Possibles

- `unauthenticated` - Utilisateur non authentifié
- `resource-exhausted` - Limite de taux dépassée
- `invalid-argument` - Paramètres invalides ou sous-total incorrect
- `not-found` - Produit introuvable
- `resource-exhausted` - Stock insuffisant
- `permission-denied` - Vendeur suspendu
- `failed-precondition` - Vendeur non approuvé

---

### 2. Webhook Stripe

**Endpoint:** `stripe_webhook`  
**Méthode:** `POST`  
**Authentification:** ❌ Non requise (signature Stripe vérifiée)  
**URL:** `/stripe_webhook`

#### En-têtes Requis

```http
Stripe-Signature: <STRIPE_SIGNATURE>
Content-Type: application/json
```

#### Événements Gérés

- `checkout.session.completed` - Session de paiement complétée
- `checkout.session.async_payment_succeeded` - Paiement asynchrone réussi
- `checkout.session.async_payment_failed` - Paiement asynchrone échoué
- `checkout.session.expired` - Session expirée
- `payment_intent.succeeded` - Intention de paiement réussie
- `payment_intent.payment_failed` - Paiement échoué
- `charge.refunded` - Remboursement effectué
- `charge.dispute.created` - Litige créé
- `charge.dispute.closed` - Litige fermé
- `transfer.reversed` - Transfert inversé
- `payout.failed` - Paiement échoué
- `refund.failed` - Remboursement échoué

#### Réponse

```
200 OK - Success
400 Bad Request - Signature invalide
500 Internal Server Error - Erreur de traitement
```

---

### 3. Capturer le Paiement

**Endpoint:** `capture_payment`  
**Méthode:** `POST` (Callable Function)  
**Authentification:** ✅ Requise

#### Paramètres

| Paramètre | Type | Requis | Description |
|-----------|------|--------|-------------|
| `orderId` | String | ✅ | ID de la commande à capturer |

#### Exemple de Requête

```json
{
  "orderId": "order_xyz789"
}
```

#### Réponse Réussie (200)

```json
{
  "success": true,
  "captured": true,
  "paymentIntentId": "pi_abc123"
}
```

#### Erreurs Possibles

- `unauthenticated` - Utilisateur non authentifié
- `invalid-argument` - orderId manquant
- `not-found` - Commande introuvable
- `permission-denied` - Pas votre commande
- `failed-precondition` - Paiement déjà capturé ou statut invalide

---

### 4. Créer un Compte Stripe Connect

**Endpoint:** `create_connect_account`  
**Méthode:** `POST` (Callable Function)  
**Authentification:** ✅ Requise

#### Paramètres

| Paramètre | Type | Requis | Description |
|-----------|------|--------|-------------|
| `email` | String | ✅ | Email du vendeur |
| `businessType` | String | ✅ | Type d'entreprise: `individual` ou `company` |
| `country` | String | ❌ | Code pays (défaut: `CA`) |

#### Exemple de Requête

```json
{
  "email": "seller@example.com",
  "businessType": "individual",
  "country": "CA"
}
```

#### Réponse Réussie (200)

```json
{
  "success": true,
  "accountId": "acct_abc123"
}
```

---

### 5. Obtenir le Statut du Compte Connect

**Endpoint:** `get_connect_account_status`  
**Méthode:** `POST` (Callable Function)  
**Authentification:** ✅ Requise

#### Paramètres

Aucun paramètre requis (utilise l'ID utilisateur authentifié)

#### Réponse Réussie (200)

```json
{
  "success": true,
  "accountId": "acct_abc123",
  "detailsSubmitted": true,
  "chargesEnabled": true,
  "payoutsEnabled": true
}
```

---

### 6. Créer un Lien d'Onboarding

**Endpoint:** `create_account_link`  
**Méthode:** `POST` (Callable Function)  
**Authentification:** ✅ Requise

#### Paramètres

| Paramètre | Type | Requis | Description |
|-----------|------|--------|-------------|
| `refreshUrl` | String | ✅ | URL de redirection en cas d'erreur |
| `returnUrl` | String | ✅ | URL de retour après succès |

#### Exemple de Requête

```json
{
  "refreshUrl": "https://origna.ca/seller/onboarding",
  "returnUrl": "https://origna.ca/seller/dashboard"
}
```

#### Réponse Réussie (200)

```json
{
  "success": true,
  "url": "https://connect.stripe.com/setup/s/abc123"
}
```

---

## Gestion des Paiements (Airwallex)

### 1. Créer un Compte Vendeur Airwallex

**Endpoint:** `airwallex_create_seller_account`  
**Méthode:** `POST` (Callable Function)  
**Authentification:** ✅ Requise

#### Paramètres

| Paramètre | Type | Requis | Description |
|-----------|------|--------|-------------|
| `email` | String | ✅ | Email du vendeur |
| `businessInfo` | Object | ✅ | Informations de l'entreprise |

#### Exemple de Requête

```json
{
  "email": "seller@example.com",
  "businessInfo": {
    "name": "Mon Entreprise",
    "registrationNumber": "123456789"
  }
}
```

#### Réponse Réussie (200)

```json
{
  "success": true,
  "accountId": "airwallex_account_123"
}
```

---

### 2. Traiter un Paiement Airwallex

**Endpoint:** `airwallex_process_payment`  
**Méthode:** `POST` (Callable Function)  
**Authentification:** ✅ Requise

#### Paramètres

| Paramètre | Type | Requis | Description |
|-----------|------|--------|-------------|
| `orderId` | String | ✅ | ID de la commande |
| `returnUrl` | String | ❌ | URL de retour après 3DS (défaut: `https://origna.ca/order-success`) |

#### Exemple de Requête

```json
{
  "orderId": "order_xyz789",
  "returnUrl": "https://origna.ca/order/xyz789/success"
}
```

#### Réponse Réussie (200)

```json
{
  "success": true,
  "paymentIntentId": "pi_airwallex_123",
  "clientSecret": "secret_abc123",
  "nextAction": {
    "type": "redirect_to_url",
    "redirect_to_url": {
      "url": "https://3ds.airwallex.com/..."
    }
  }
}
```

---

### 3. Capturer un Paiement Airwallex

**Endpoint:** `airwallex_capture_payment`  
**Méthode:** `POST` (Callable Function)  
**Authentification:** ✅ Requise

#### Paramètres

| Paramètre | Type | Requis | Description |
|-----------|------|--------|-------------|
| `orderId` | String | ✅ | ID de la commande |

#### Réponse Réussie (200)

```json
{
  "success": true,
  "captured": true
}
```

---

### 4. Webhook Airwallex

**Endpoint:** `airwallex_webhook`  
**Méthode:** `POST`  
**Authentification:** ❌ Non requise (signature vérifiée)

#### En-têtes Requis

```http
X-Airwallex-Signature: <AIRWALLEX_SIGNATURE>
Content-Type: application/json
```

---

## Gestion des Produits

### 1. Télécharger des Images de Produits

**Endpoint:** `upload_product_images`  
**Méthode:** `POST` (Callable Function)  
**Authentification:** ✅ Requise

#### Paramètres

| Paramètre | Type | Requis | Description |
|-----------|------|--------|-------------|
| `fileNames` | Array[String] | ✅ | Noms des fichiers (max 5) |
| `contentTypes` | Array[String] | ✅ | Types MIME des fichiers |

#### Exemple de Requête

```json
{
  "fileNames": ["image1.jpg", "image2.png"],
  "contentTypes": ["image/jpeg", "image/png"]
}
```

#### Réponse Réussie (200)

```json
{
  "success": true,
  "uploadUrls": [
    {
      "uploadUrl": "https://r2.cloudflarestorage.com/...",
      "publicUrl": "https://cdn.origna.ca/products/uuid1.jpg",
      "fileName": "image1.jpg",
      "key": "products/uuid1.jpg"
    },
    {
      "uploadUrl": "https://r2.cloudflarestorage.com/...",
      "publicUrl": "https://cdn.origna.ca/products/uuid2.png",
      "fileName": "image2.png",
      "key": "products/uuid2.png"
    }
  ]
}
```

#### Erreurs Possibles

- `unauthenticated` - Utilisateur non authentifié
- `invalid-argument` - Fichiers manquants, trop de fichiers (max 5), ou types MIME invalides
- `failed-precondition` - Identifiants R2 non configurés

---

### 2. Supprimer un Produit

**Endpoint:** `delete_product`  
**Méthode:** `POST` (Callable Function)  
**Authentification:** ✅ Requise

#### Paramètres

| Paramètre | Type | Requis | Description |
|-----------|------|--------|-------------|
| `productId` | String | ✅ | ID du produit à supprimer |

#### Exemple de Requête

```json
{
  "productId": "prod_123"
}
```

#### Réponse Réussie (200)

```json
{
  "success": true,
  "message": "Product deleted successfully"
}
```

#### Erreurs Possibles

- `unauthenticated` - Utilisateur non authentifié
- `invalid-argument` - productId manquant
- `not-found` - Produit ou utilisateur introuvable
- `permission-denied` - Seul le propriétaire ou admin peut supprimer
- `failed-precondition` - Commandes en attente existent pour ce produit

---

### 3. Soumettre une Évaluation de Produit

**Endpoint:** `submit_product_rating`  
**Méthode:** `POST` (Callable Function)  
**Authentification:** ✅ Requise

#### Paramètres

| Paramètre | Type | Requis | Description |
|-----------|------|--------|-------------|
| `productId` | String | ✅ | ID du produit à évaluer |
| `orderId` | String | ✅ | ID de la commande (vérification) |
| `rating` | Number | ✅ | Note de 1 à 5 |
| `review` | String | ❌ | Commentaire (max 1000 caractères) |

#### Exemple de Requête

```json
{
  "productId": "prod_123",
  "orderId": "order_xyz789",
  "rating": 5,
  "review": "Excellent produit, très satisfait!"
}
```

#### Réponse Réussie (200)

```json
{
  "success": true,
  "newRating": 4.7,
  "ratingCount": 123
}
```

#### Erreurs Possibles

- `unauthenticated` - Utilisateur non authentifié
- `invalid-argument` - Paramètres manquants ou note invalide (doit être 1-5)
- `not-found` - Commande ou produit introuvable
- `permission-denied` - Pas votre commande
- `failed-precondition` - Commande pas encore livrée
- `already-exists` - Produit déjà évalué par cet utilisateur

---

### 4. Obtenir les Produits Paginés

**Endpoint:** `get_products_paginated`  
**Méthode:** `POST` (Callable Function)  
**Authentification:** ❌ Non requise

#### Paramètres

| Paramètre | Type | Requis | Description |
|-----------|------|--------|-------------|
| `limit` | Number | ❌ | Nombre de produits (défaut: 20, max: 100) |
| `startAfter` | String | ❌ | ID du document pour commencer après (cursor) |
| `category` | String | ❌ | Filtrer par catégorie |
| `sellerId` | String | ❌ | Filtrer par vendeur |
| `isActive` | Boolean | ❌ | Filtrer par statut actif (défaut: true) |
| `orderBy` | String | ❌ | Champ de tri: `createdAt`, `price`, `rating`, `ratingCount`, `title` (défaut: `createdAt`) |
| `orderDirection` | String | ❌ | Direction: `asc` ou `desc` (défaut: `desc`) |

#### Exemple de Requête

```json
{
  "limit": 20,
  "category": "Electronics",
  "orderBy": "price",
  "orderDirection": "asc"
}
```

#### Réponse Réussie (200)

```json
{
  "success": true,
  "products": [
    {
      "id": "prod_123",
      "title": "T-Shirt",
      "price": 29.99,
      "rating": 4.5,
      "ratingCount": 50,
      "imageUrls": ["https://cdn.origna.ca/products/..."],
      "sellerId": "seller_456",
      "category": "Clothing",
      "isActive": true,
      "stockQuantity": 100,
      "createdAt": "2026-01-15T10:30:00Z"
    }
  ],
  "nextCursor": "prod_124",
  "hasMore": true,
  "totalFetched": 20
}
```

---

### 5. Obtenir les Produits d'un Vendeur

**Endpoint:** `get_seller_products_paginated`  
**Méthode:** `POST` (Callable Function)  
**Authentification:** ✅ Requise (pour voir ses propres produits inactifs)

#### Paramètres

| Paramètre | Type | Requis | Description |
|-----------|------|--------|-------------|
| `sellerId` | String | ❌ | ID du vendeur (utilise l'utilisateur connecté si omis) |
| `limit` | Number | ❌ | Nombre de produits (défaut: 20, max: 100) |
| `startAfter` | String | ❌ | Document ID cursor |
| `includeInactive` | Boolean | ❌ | Inclure produits inactifs (propriétaire/admin uniquement) |

#### Réponse Réussie (200)

```json
{
  "success": true,
  "products": [...],
  "nextCursor": "prod_125",
  "hasMore": false,
  "totalFetched": 15
}
```

---

### 6. Configurer l'Index Algolia

**Endpoint:** `configure_algolia`  
**Méthode:** `POST` (Callable Function)  
**Authentification:** ✅ Requise (Admin uniquement)

#### Paramètres

Aucun paramètre requis

#### Réponse Réussie (200)

```json
{
  "success": true,
  "message": "Algolia index configured"
}
```

---

### 7. Notifications de Retour en Stock

**Endpoints:** `subscribe_stock_notification`, `unsubscribe_stock_notification`  
**Méthode:** `POST` (Callable Function)  
**Authentification:** ✅ Requise

#### Paramètres

| Paramètre | Type | Requis | Description |
|-----------|------|--------|-------------|
| `productId` | String | ✅ | ID du produit |

---

### 8. Questions et Réponses (Q&A)

**Endpoints:** `ask_product_question`, `answer_product_question`, `get_product_questions`  
**Authentification:** ✅ Requise (sauf `get_product_questions`)

#### ask_product_question (Acheteur)
| Paramètre | Type | Requis | Description |
|-----------|------|--------|-------------|
| `productId` | String | ✅ | ID du produit |
| `question` | String | ✅ | Texte de la question |

#### answer_product_question (Vendeur)
| Paramètre | Type | Requis | Description |
|-----------|------|--------|-------------|
| `questionId` | String | ✅ | ID de la question |
| `answer` | String | ✅ | Texte de la réponse |

---

## Gestion des Commandes

### 1. Confirmer la Réception de Commande

**Endpoint:** `confirm_order_receipt`  
**Méthode:** `POST` (Callable Function)  
**Authentification:** ✅ Requise

#### Paramètres

| Paramètre | Type | Requis | Description |
|-----------|------|--------|-------------|
| `orderId` | String | ✅ | ID de la commande |

#### Exemple de Requête

```json
{
  "orderId": "order_xyz789"
}
```

#### Réponse Réussie (200)

```json
{
  "success": true,
  "captured": true
}
```

#### Actions Effectuées

1. Capture le paiement Stripe
2. Met à jour le statut de la commande à `delivered`
3. Crée des enregistrements de paiement pour chaque vendeur
4. Transfère les fonds aux vendeurs (moins 2.5% de frais de plateforme)

#### Erreurs Possibles

- `unauthenticated` - Utilisateur non authentifié
- `invalid-argument` - orderId manquant
- `not-found` - Commande introuvable
- `permission-denied` - Pas votre commande
- `failed-precondition` - Statut de commande invalide ou pas d'intention de paiement

---

### 2. Mettre à Jour le Statut de Commande

**Endpoint:** `update_order_status`  
**Méthode:** `POST` (Callable Function)  
**Authentification:** ✅ Requise (Vendeur ou Admin)

#### Paramètres

| Paramètre | Type | Requis | Description |
|-----------|------|--------|-------------|
| `orderId` | String | ✅ | ID de la commande |
| `newStatus` | String | ✅ | Nouveau statut: `processing`, `shipped`, `delivered`, `cancelled` |
| `trackingNumber` | String | ❌ | Numéro de suivi (pour statut `shipped`) |
| `carrier` | String | ❌ | Transporteur (pour statut `shipped`) |

#### Exemple de Requête

```json
{
  "orderId": "order_xyz789",
  "newStatus": "shipped",
  "trackingNumber": "1Z999AA10123456784",
  "carrier": "UPS"
}
```

#### Réponse Réussie (200)

```json
{
  "success": true,
  "orderStatus": "shipped"
}
```

#### Transitions de Statut Valides

- `pending` → `confirmed`, `cancelled`
- `confirmed` → `processing`, `cancelled`
- `processing` → `shipped`, `cancelled`
- `shipped` → `delivered`, `cancelled`
- `delivered` → (terminal)
- `cancelled` → (terminal)

---

### 3. Annuler une Commande

**Endpoint:** `cancel_order`  
**Méthode:** `POST` (Callable Function)  
**Authentification:** ✅ Requise

#### Paramètres

| Paramètre | Type | Requis | Description |
|-----------|------|--------|-------------|
| `orderId` | String | ✅ | ID de la commande |
| `reason` | String | ✅ | Raison de l'annulation |

#### Exemple de Requête

```json
{
  "orderId": "order_xyz789",
  "reason": "Client a changé d'avis"
}
```

#### Réponse Réussie (200)

```json
{
  "success": true,
  "refunded": true,
  "refundAmount": 59.98
}
```

#### Actions Effectuées

1. Annule le paiement Stripe (si pas encore capturé)
2. Rembourse le client (si déjà capturé)
3. Restaure le stock des produits
4. Met à jour le statut à `cancelled`

---

### 4. Approuver les Frais de Livraison

**Endpoint:** `approve_shipping_cost`  
**Méthode:** `POST` (Callable Function)  
**Authentification:** ✅ Requise

#### Paramètres

| Paramètre | Type | Requis | Description |
|-----------|------|--------|-------------|
| `orderId` | String | ✅ | ID de la commande |
| `approved` | Boolean | ✅ | Approuvé ou refusé |

#### Exemple de Requête

```json
{
  "orderId": "order_xyz789",
  "approved": true
}
```

#### Réponse Réussie (200)

```json
{
  "success": true,
  "shippingApproved": true
}
```

---

### 5. Demandes de Retour

**Endpoints:** `create_return_request`, `approve_return_request`, `reject_return_request`  
**Authentification:** ✅ Requise

#### create_return_request (Acheteur)
| Paramètre | Type | Requis | Description |
|-----------|------|--------|-------------|
| `orderId` | String | ✅ | ID de la commande |
| `itemId` | String | ✅ | ID de l'article |
| `reason` | String | ✅ | Raison du retour |

#### approve_return_request (Vendeur/Admin)
| Paramètre | Type | Requis | Description |
|-----------|------|--------|-------------|
| `requestId` | String | ✅ | ID de la demande de retour |

---

## Chat et Communications

### 1. Obtenir ou Créer une Conversation

**Endpoint:** `get_or_create_chat`  
**Méthode:** `POST` (Callable Function)  
**Authentification:** ✅ Requise (Premium uniquement)

#### Paramètres

| Paramètre | Type | Requis | Description |
|-----------|------|--------|-------------|
| `otherUserId` | String | ✅ | ID de l'autre participant |
| `productId` | String | ❌ | ID du produit lié à la conversation |

#### Réponse Réussie (200)

```json
{
  "success": true,
  "chatId": "chat_abc123"
}
```

---

### 2. Envoyer un Message

**Endpoint:** `send_message`  
**Méthode:** `POST` (Callable Function)  
**Authentification:** ✅ Requise

#### Paramètres

| Paramètre | Type | Requis | Description |
|-----------|------|--------|-------------|
| `chatId` | String | ✅ | ID de la conversation |
| `text` | String | ✅ | Texte du message |

---

### 3. Marquer comme Lu

**Endpoint:** `mark_messages_read`  
**Méthode:** `POST` (Callable Function)  
**Authentification:** ✅ Requise

#### Paramètres

| Paramètre | Type | Requis | Description |
|-----------|------|--------|-------------|
| `chatId` | String | ✅ | ID de la conversation |

---

## Gestion des Adresses

### 1. Ajouter une Adresse
**Endpoint:** `add_buyer_address`

### 2. Mettre à Jour une Adresse
**Endpoint:** `update_buyer_address`

### 3. Supprimer une Adresse
**Endpoint:** `delete_buyer_address`

---

## Produits Numériques et Licences

### 1. Activer une Licence
**Endpoint:** `activate_license`

### 2. Générer une Session de Téléchargement
**Endpoints:** `generate_book_download_session`, `generate_software_download_session`

---

## Administration

**Endpoint:** `suspend_seller`  
**Méthode:** `POST` (Callable Function)  
**Authentification:** ✅ Requise (Admin avec MFA récent < 5 min)

#### Paramètres

| Paramètre | Type | Requis | Description |
|-----------|------|--------|-------------|
| `sellerId` | String | ✅ | ID du vendeur à suspendre |
| `reason` | String | ✅ | Raison de la suspension |
| `permanent` | Boolean | ❌ | Suspension permanente (défaut: false) |

#### Exemple de Requête

```json
{
  "sellerId": "seller_456",
  "reason": "Violation des conditions d'utilisation",
  "permanent": false
}
```

#### Réponse Réussie (200)

```json
{
  "success": true,
  "suspended": true,
  "productsDeactivated": 25,
  "ordersCancelled": 3
}
```

#### Actions Effectuées

1. Marque l'utilisateur comme suspendu
2. Désactive tous les produits du vendeur
3. Annule toutes les commandes en attente/confirmées
4. Crée une alerte de sécurité

---

### 3. Inscription MFA Admin

**Endpoint:** `admin_mfa_enroll`  
**Méthode:** `POST` (Callable Function)  
**Authentification:** ✅ Requise (Admin uniquement)

#### Paramètres

Aucun paramètre requis

#### Réponse Réussie (200)

```json
{
  "success": true,
  "secret": "JBSWY3DPEHPK3PXP",
  "qrCode": "otpauth://totp/Origna:admin@example.com?secret=JBSWY3DPEHPK3PXP&issuer=Origna"
}
```

---

### 4. Vérifier le Code MFA

**Endpoint:** `admin_mfa_verify`  
**Méthode:** `POST` (Callable Function)  
**Authentification:** ✅ Requise (Admin uniquement)

#### Paramètres

| Paramètre | Type | Requis | Description |
|-----------|------|--------|-------------|
| `token` | String | ✅ | Code MFA à 6 chiffres |

#### Exemple de Requête

```json
{
  "token": "123456"
}
```

#### Réponse Réussie (200)

```json
{
  "success": true,
  "verified": true
}
```

---

### 5. Désactiver MFA

**Endpoint:** `admin_mfa_disable`  
**Méthode:** `POST` (Callable Function)  
**Authentification:** ✅ Requise (Admin avec MFA récent)

#### Paramètres

| Paramètre | Type | Requis | Description |
|-----------|------|--------|-------------|
| `token` | String | ✅ | Code MFA pour confirmation |

#### Exemple de Requête

```json
{
  "token": "123456"
}
```

#### Réponse Réussie (200)

```json
{
  "success": true,
  "mfaDisabled": true
}
```

---

### 6. Supprimer un Compte

**Endpoint:** `delete_account`  
**Méthode:** `POST` (Callable Function)  
**Authentification:** ✅ Requise

#### Paramètres

| Paramètre | Type | Requis | Description |
|-----------|------|--------|-------------|
| `userId` | String | ✅ | ID du compte à supprimer |
| `confirmPassword` | String | ✅ | Mot de passe pour confirmation |

#### Exemple de Requête

```json
{
  "userId": "user_abc123",
  "confirmPassword": "mySecurePassword123"
}
```

#### Réponse Réussie (200)

```json
{
  "success": true,
  "deleted": true
}
```

#### Actions Effectuées

1. Anonymise les données personnelles dans Firestore
2. Supprime le compte Firebase Auth
3. Crée un log d'audit

---

## Tâches Planifiées (Cron)

### 1. Capture Automatique des Paiements

**Fonction:** `auto_capture_confirmed_receipts`  
**Planification:** Quotidienne (01:00 UTC)  
**Description:** Capture automatiquement les paiements pour les commandes livrées depuis 7+ jours

---

### 2. Vérifier les Autorisations Expirées

**Fonction:** `check_expired_authorizations`  
**Planification:** Quotidienne (02:00 UTC)  
**Description:** Annule les commandes avec autorisation de paiement expirée (14 jours)

---

### 3. Archiver les Anciennes Commandes

**Fonction:** `auto_archive_old_orders`  
**Planification:** Toutes les 12 heures  
**Description:** Archive les commandes complétées/annulées de plus de 90 jours

---

### 4. Surveiller la Synchronisation Algolia

**Fonction:** `monitor_algolia_sync`  
**Planification:** Toutes les 15 minutes  
**Description:** Vérifie que l'index Algolia est synchronisé avec Firestore

---

### 5. Nettoyer les Limites de Taux Obsolètes

**Fonction:** `cleanup_stale_rate_limits`  
**Planification:** Toutes les 30 minutes  
**Description:** Supprime les enregistrements de limite de taux expirés

---

### 6. Envoyer les Métriques Quotidiennes

**Fonction:** `send_daily_metrics`  
**Planification:** Quotidienne (02:00 UTC)  
**Description:** Envoie un rapport quotidien des métriques de la plateforme aux admins

---

## Codes d'Erreur

### Codes d'Erreur Firebase Functions

| Code | Description | Action Recommandée |
|------|-------------|-------------------|
| `ok` | Succès | - |
| `cancelled` | Opération annulée | Réessayer |
| `unknown` | Erreur inconnue | Contacter le support |
| `invalid-argument` | Argument invalide | Vérifier les paramètres |
| `deadline-exceeded` | Délai dépassé | Réessayer |
| `not-found` | Ressource introuvable | Vérifier l'ID |
| `already-exists` | Ressource existe déjà | Utiliser une ressource existante |
| `permission-denied` | Permission refusée | Vérifier les droits d'accès |
| `resource-exhausted` | Limite de taux dépassée | Attendre et réessayer |
| `failed-precondition` | Précondition échouée | Vérifier l'état de la ressource |
| `aborted` | Opération abandonnée | Réessayer avec backoff exponentiel |
| `out-of-range` | Hors de portée | Ajuster les paramètres |
| `unimplemented` | Non implémenté | Utiliser une autre méthode |
| `internal` | Erreur interne | Contacter le support |
| `unavailable` | Service indisponible | Réessayer plus tard |
| `data-loss` | Perte de données | Contacter le support immédiatement |
| `unauthenticated` | Non authentifié | Se reconnecter |

### Codes d'Erreur HTTP Stripe

| Code | Description |
|------|-------------|
| `200` | Succès |
| `400` | Requête invalide |
| `401` | Non autorisé (clé API invalide) |
| `402` | Échec de la requête |
| `403` | Accès interdit |
| `404` | Ressource introuvable |
| `409` | Conflit |
| `429` | Trop de requêtes |
| `500, 502, 503, 504` | Erreurs serveur Stripe |

### Codes de Statut Commande

| Statut | Description |
|--------|-------------|
| `pending` | En attente de paiement |
| `confirmed` | Paiement confirmé |
| `processing` | En cours de traitement |
| `shipped` | Expédiée |
| `delivered` | Livrée |
| `cancelled` | Annulée |

### Codes de Statut Paiement

| Statut | Description |
|--------|-------------|
| `pending` | En attente |
| `authorized` | Autorisé (pas encore capturé) |
| `captured` | Capturé (fonds transférés) |
| `failed` | Échoué |
| `refunded` | Remboursé |
| `cancelled` | Annulé |

---

## Notes de Sécurité

### 1. Rate Limiting

- **Checkout:** 5 requêtes/minute par utilisateur
- **Webhooks:** Vérification de signature obligatoire
- **Admin:** MFA requis pour opérations sensibles (validité: 5 minutes)

### 2. Validation des Données

- Tous les prix sont validés côté serveur
- Les sous-totaux ont une tolérance de 1%
- Les stocks sont réservés atomiquement avec transactions Firestore
- Les entrées utilisateur sont sanitisées pour prévenir XSS/injection

### 3. Authentification

- Firebase Auth JWT requis pour toutes les fonctions callable
- Custom claims pour les rôles: `admin`, `seller`, `buyer`
- Webhooks: Vérification de signature cryptographique

### 4. Audit Trail

- Tous les webhooks sont loggés avec IP client
- Changements de rôles loggés dans `security_alerts`
- Suspensions de vendeurs créent des alertes de sécurité

---

## Support

Pour toute question ou problème:

- **Email:** support@origna.ca
- **Documentation:** https://docs.origna.ca
- **Status:** https://status.origna.ca

---

**Dernière mise à jour:** 3 février 2026  
**Version de l'API:** 1.1

---

## Appendix A — Endpoints Complets

### Stripe: Vérification de Panier

| Endpoint | Auth | Description |
|----------|------|-------------|
| `verify_cart_prices` | ✅ | Vérifie les prix du panier vs Firestore avant checkout |

### Stripe: Webhooks Internes (Non-callable)

| Handler | Déclenché par | Description |
|---------|---------------|-------------|
| `process_charge_refunded` | `charge.refunded` | Met à jour le statut de remboursement |
| `process_dispute_created` | `charge.dispute.created` | Reverse les transferts + alerte sécurité |
| `process_dispute_updated` | `charge.dispute.updated` | Log l'évolution du litige |
| `process_dispute_closed` | `charge.dispute.closed` | Résolution: restaure statut ou annule |
| `process_dispute_funds_reinstated` | `charge.dispute.funds_reinstated` | Fonds réinstaurés après litige gagné |

### Produits — Endpoints Complémentaires

| Endpoint | Auth | Description |
|----------|------|-------------|
| `get_product_ratings_paginated` | ❌ | Évaluations paginées d'un produit |
| `get_seller_products_paginated` | ❌ | Produits d'un vendeur spécifique |
| `submit_product_rating` | ✅ | Soumettre une évaluation (acheteur vérifié) |

### Produits — Triggers Firestore (Non-callable)

| Trigger | Événement | Description |
|---------|-----------|-------------|
| `on_product_created` | Document créé | Sync Algolia + validation magic bytes |
| `on_product_updated` | Document modifié | Mise à jour index Algolia |
| `on_product_deleted` | Document supprimé | Suppression de l'index Algolia |

### Commandes — Endpoints Complémentaires

| Endpoint | Auth | Description |
|----------|------|-------------|
| `update_item_status` | ✅ Vendeur | Mettre à jour le statut d'un article + tracking number |
| `refund_order_item` | ✅ Admin/Vendeur | Rembourser un article spécifique |
| `update_shipping_cost` | ✅ Vendeur | Mettre à jour le coût de livraison réel |
| `on_order_status_changed` | Trigger | Notifications automatiques sur changement de statut |

### Administration — Endpoints Complémentaires

| Endpoint | Auth | MFA | Description |
|----------|------|-----|-------------|
| `unsuspend_seller` | ✅ Admin | ✅ | Réactiver un vendeur suspendu |
| `admin_update_product_stock` | ✅ Admin | ✅ | Modifier le stock d'un produit |
| `admin_mfa_verify_backup` | ✅ Admin | — | Vérifier un code de secours MFA |
| `export_my_data` | ✅ | — | Export PIPEDA: toutes les données utilisateur |
| `unsubscribe_email` | ✅ | — | Désinscription CASL marketing emails |

### Profil Utilisateur

| Endpoint | Auth | Description |
|----------|------|-------------|
| `update_user_profile` | ✅ | Mettre à jour le profil (nom, adresse, etc.) |
| `get_user_profile` | ✅ | Récupérer le profil complet |
| `update_email_consent` | ✅ | Mettre à jour le consentement email |

### Fournisseurs de Paiement

| Endpoint | Auth | Description |
|----------|------|-------------|
| `get_payment_providers` | ✅ Admin | Liste des fournisseurs et leur statut |
| `update_payment_provider` | ✅ Admin | Activer/désactiver un fournisseur |
| `get_provider_status` | ✅ Admin | Statut détaillé d'un fournisseur |

### Livraison

| Endpoint | Auth | Description |
|----------|------|-------------|
| `calculate_shipping_cost` | ✅ | Calculer le coût de livraison (distance + province) |

### Tâches Planifiées (Cron) — Liste Complète

| Task | Fréquence | Description |
|------|-----------|-------------|
| `auto_capture_confirmed_receipts` | 15 min | Capture les paiements autorisés après confirmation |
| `check_expired_authorizations` | 1h | Annule les autorisations Stripe expirées (>6j) |
| `auto_archive_old_orders` | 24h | Archive les commandes complétées >90j |
| `monitor_algolia_sync` | 15 min | Vérifie la cohérence Firestore↔Algolia (>5% = alerte) |
| `cleanup_stale_rate_limits` | 30 min | Supprime les rate limits >1h |
| `cleanup_orphaned_r2_images` | 24h | Supprime les images R2 non référencées (>24h) |
| `cleanup_stale_webhook_events` | 24h | Supprime les events webhook >7j |
| `cleanup_stale_security_alerts` | 24h | Archive les alertes résolues >90j |
| `retry_failed_algolia_syncs` | 1h | Retry DLQ Algolia (max 5 tentatives) |