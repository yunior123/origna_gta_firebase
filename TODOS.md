


## External Manual Backlog (Future)

Console Firebase — Supprimer l'ancien app iOS com.example.orignaGta, ajouter la nouvelle avec ca.orignagta.app, re-télécharger GoogleService-Info.plist (il manquera le REVERSED_CLIENT_ID pour Google Sign-In)
Apple Developer Portal — Créer l'App ID ca.orignagta.app, activer les capabilities Push Notifications et Associated Domains
APNs — Créer une clé APNs (ou certificat) et l'uploader dans Firebase Console → Project Settings → Cloud Messaging → Apple app
Déployer le AASA — Le fichier apple-app-site-association est dans web/.well-known/ — il sera servi automatiquement si le site est hosté avec Firebase Hosting (ajouter un rewrite dans firebase.json si nécessaire avec Content-Type: application/json)
Google Sign-In — Après régénération du GoogleService-Info.plist, ajouter le REVERSED_CLIENT_ID comme URL scheme supplémentaire dans Info.plist


Voici les 3 entitlements à activer dans le Apple Developer Portal (Identifiers → ca.orignagta.app → Capabilities) :

Capability	Entitlement	Pourquoi
Push Notifications	aps-environment	Firebase Cloud Messaging / notifications de commandes
Associated Domains	com.apple.developer.associated-domains	Universal Links pour les retours Stripe (/payment-success, /seller-return, etc.)
Sign in with Apple	com.apple.developer.applesignin	Obligatoire — Apple rejette les apps qui offrent Google Sign-In sans aussi offrir Sign in with Apple (App Store Review Guideline 4.8)
Étapes dans le portail Apple :
Identifiers → Create/Edit App ID ca.orignagta.app
Cocher : ✅ Push Notifications, ✅ Associated Domains, ✅ Sign in with Apple
Keys → Créer une clé APNs → l'uploader dans Firebase Console (Project Settings → Cloud Messaging)
Profiles → Générer un Provisioning Profile de développement et de distribution avec ces capabilities
Changer aps-environment de development à production avant la soumission App Store
Note importante : Puisque vous offrez Google Sign-In, vous devrez aussi implémenter Sign in with Apple dans l'app Flutter (package sign_in_with_apple) avant de soumettre sur l'App Store — c'est une exigence Apple.

Ce qui nécessite l'Apple Developer Program ($99/an) :
Feature	Pourquoi
Push Notifications	Capability aps-environment
Universal Links (retour auto depuis Stripe)	Capability Associated Domains
Sign in with Apple	Capability + obligatoire pour l'App Store si tu offres Google Sign-In
App Store submission	Distribution via TestFlight ou App Store


cd /Users/yuniorrodriguezosorio/Documents/GitHub/origna_gta/origna_gta && sed -i '' '/CODE_SIGN_ENTITLEMENTS = Runner\/Runner.entitlements;/d' ios/Runner.xcodeproj/project.pbxproj
Les 3 références CODE_SIGN_ENTITLEMENTS sont supprimées. Tu peux maintenant relancer flutter run. Le fichier Runner.entitlements reste dans le repo pour plus tard quand tu auras le Apple Developer Program — il suffira de réajouter les lignes dans le pbxproj.
For future manual setup:
0. google mcp integration
1. mcp for api
2. web mcp
3. docs for 1 and 2




10.**Cloud Scheduler frequency** — Cron jobs should run at the minimum effective frequency (e.g. every 5 minutes, not every minute) to reduce invocations while still meeting timing requirements.


11. mcp for store


# Add Product — Full Code Audit
**Files audited:** `Product.json`, `add_product_state.dart`, `add_product_viewmodel.dart`, `addproduct_screen.dart`, `product_repository.dart`, `supplier_config.dart`, `schema_constants.dart`

---


22. playwright ai agents integration


33. create a system similar to this to track schema, it should also include subcollection, collection organization, do it collection by collection when it comes to db to have a clear understanding

## 5. Cross-Stack Field Verification ✅

| Field         | Dart (Fields.*)  | Python (Fields.*) | Firestore Value  | Status |
|---------------|-----------------|-------------------|-----------------|--------|
| questionText  | questionText     | QUESTION_TEXT     | 'question'      | ✅ Match |
| answerText    | answerText       | ANSWER_TEXT       | 'answer'        | ✅ Match |
| askerId       | askerId          | ASKER_ID          | 'askerId'       | ✅ Match |
| isAnswered    | isAnswered       | IS_ANSWERED       | 'isAnswered'    | ✅ Match |
| sellerId      | sellerId         | SELLER_ID         | 'sellerId'      | ✅ Match |
| productId     | productId        | PRODUCT_ID        | 'productId'     | ✅ Match |
| questionId    | questionId       | QUESTION_ID       | 'questionId'    | ✅ Match |
| upvotes       | upvotes          | UPVOTES           | 'upvotes'       | ✅ Match |



- **[F-175]** Missing variant-specific images (High return rate risk).

- **[F-43]** No UCP machine-readable discovery (Agentic commerce gap).

### [F-47] AI-Assisted Listing
Implement "Magic Upload": generate product name, description, and categories from a single image.
- **Priority:** P1 (Seller experience).

### [F-44] AI-Dispute Mediation
Use RAG-based LLMs to auto-resolve 70% of buyer/seller disputes without admin intervention.
- **Priority:** P1 (Scalability).

- **[F-43]** No UCP machine-readable discovery (Agentic commerce gap).
- **Decision [F-43]**: UCP (Universal Commerce Protocol) implementation needs detailed specification for the machine-readable endpoint.


- **[F-239] Photo Moderation:** No automated safety check (Google Vision) for review photos.

 I will examine e2e/playwright.config.dev.ts to determine whether it targets a remote environment or requires local
  emulators.

╭───────────────────────────────────────────────────────────────────────────────────────────────────────────────────╮
│ ✓  ReadFile e2e/playwright.config.dev.ts                                                                          │
│                                                                                                                   │
╰───────────────────────────────────────────────────────────────────────────────────────────────────────────────────╯
✦ I will read scripts/deploy_rules.sh to understand its deployment target and ensure it doesn't inadvertently deploy to
  an unintended environment.

╭───────────────────────────────────────────────────────────────────────────────────────────────────────────────────╮
│ ✓  ReadFile scripts/deploy_rules.sh                                                                               │
│                                                                                                                   │
╰───────────────────────────────────────────────────────────────────────────────────────────────────────────────────╯
✦ I will read scripts/install_git_hooks.sh to see how the git hooks are configured and which scripts they are intended to
  trigger.

╭───────────────────────────────────────────────────────────────────────────────────────────────────────────────────╮
│ ✓  ReadFile scripts/install_git_hooks.sh                                                                          │
│                                                                                                                   │
╰───────────────────────────────────────────────────────────────────────────────────────────────────────────────────╯
✦ I will check the Firebase login status to ensure I have the necessary permissions to execute the deployment steps in
  the pre-push hook.

╭───────────────────────────────────────────────────────────────────────────────────────────────────────────────────╮
│ ✓  Shell firebase projects:list [current working directory /Users/yuniorrodriguezosorio/Documents/GitHub/origna_… │
│                                                                                                                   │
│ ├───────────────────────┼─────────────────────────┼────────────────┼─────────────────────────┤                    │
│ │ origna-ventures       │ origna-ventures         │ 651976388489   │ [Not specified]         │                    │
│ ├───────────────────────┼─────────────────────────┼────────────────┼─────────────────────────┤                    │
│ │ OrignaGTA             │ orignagta               │ 935641055788   │ [Not specified]         │                    │
│ ├───────────────────────┼─────────────────────────┼────────────────┼─────────────────────────┤                    │
│ │ OrignaGTA Dev         │ orignagta-dev (current) │ 245187519087   │ [Not specified]         │                    │
│ ├───────────────────────┼─────────────────────────┼────────────────┼─────────────────────────┤                    │
│ │ OrignaGTA Staging     │ orignagta-staging       │ 440582189942   │ [Not specified]         │                    │
│ ├───────────────────────┼─────────────────────────┼────────────────┼─────────────────────────┤                    │
│ │ OrignaL               │ orignal-interactive     │ 41434084644    │ [Not specified]         │                    │
│ ├───────────────────────┼─────────────────────────┼────────────────┼─────────────────────────┤                    │
│ │ ucidevs               │ ucidevs-3947e           │ 411288328981   │ northamerica-northeast1 │  






why were these removed, how are disputes handled in the code

    # Dispute handlers
    "process_charge_refunded",
    "process_dispute_created",
    "process_dispute_closed",
    "process_dispute_updated",
    "process_dispute_funds_reinstated",


23. make sure that our app is not vulnerable to 
-ransomware
-man in the middle attacks
-brute force attacks
-api attacks
-dos or ddos- reflective - spoofing attack - amplified attack-dns attack
-brute force attack or dictionary attack
-vlan hopping
-rouge wireless access
-phishing attacks
- arp poisoning or spoofing

25. create cybersecurity expert agent and skills if not already that will try to hack pour app and create 
guard rails to prevent that. 


26. use nids to monitor network and endpoint detection and response
-scan emails and attachements to prevent malware infections.

28. encrypt pII data including pci for creadit card data
use data masking and anonymization where possible.

cd e2e && npx playwright test playwright_ui/add-product-e2e.spec.ts -g "T06" --config pl… (Tab to focus) │
│          

recatchpa google


 npx playwright show-report 

  cd e2e && npx playwright test playwright_ui/add-product-e2e.spec.ts -g "T06" --config playwright.config… │
│          
ell cd e2e && npx playwright test playwright_ui/add-product-e2e.spec.ts -g "T13" --config playwright.config.dev.ts [current … │
│                                                                                                                                    │
│    ✅ Flutter initialized in 679ms                



 export CLAUDE_CODE_USE_BEDROCK=1

 unset CLAUDE_CODE_USE_BEDROCK