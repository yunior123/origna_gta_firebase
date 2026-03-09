# 🚀 Déploiement Automatique Configuré

## ✅ Configuration Complète

Le déploiement automatique est **actif** via GitHub Actions sur chaque push vers `main`.

### 📋 Workflow: `.github/workflows/deploy.yml`

**Déclencheur**: `push` vers branche `main`

**Pipeline Complet**:
```yaml
1. 🔍 Tests & Quality Checks
   ├── Flutter analyze
   ├── Flutter tests
   ├── Dart unit tests
   └── Python pytest (backend)

2. 🏗️ Build
   └── Flutter web (--release)

3. 🚀 Déploiements Automatiques
   ├── Firebase Hosting    (Flutter web app)
   ├── Cloud Functions     (Backend Python)
   ├── Firestore Rules     (Sécurité)
   └── Firestore Indexes   (Performance)
```

### 🔐 Secrets Requis (GitHub)

Le workflow nécessite ces secrets dans les Settings → Secrets and variables → Actions:

```
GITHUB_TOKEN                 ✅ (Auto-généré par GitHub)
FIREBASE_SERVICE_ACCOUNT     🔑 (Service Account JSON)
```

#### Générer FIREBASE_SERVICE_ACCOUNT:

```bash
# 1. Créer le service account dans Firebase Console
firebase login
firebase projects:list

# 2. Générer la clé
gcloud iam service-accounts keys create service-account.json \
  --iam-account=firebase-adminsdk-XXXXX@orignagta.iam.gserviceaccount.com

# 3. Copier tout le contenu du JSON et l'ajouter comme secret GitHub
cat service-account.json

# 4. Supprimer le fichier local (sécurité)
rm service-account.json
```

### 🎯 Commandes Déployées Automatiquement

Sur chaque push vers `main`:

```bash
# Hosting
firebase deploy --only hosting

# Functions (avec --force pour éviter les prompts)
firebase deploy --only functions --force

# Rules
firebase deploy --only firestore:rules

# Indexes
firebase deploy --only firestore:indexes
```

### 🧪 Tester Localement Avant Push

```bash
# 1. Vérifier que les tests passent
cd functions && python -m pytest tests/ -v
cd ../origna_gta && flutter test

# 2. Build local
cd origna_gta && flutter build web

# 3. Tester les functions localement
cd functions && firebase emulators:start

# 4. Push vers main (déclenchera le workflow)
git push origin main
```

### 📊 Monitoring des Déploiements

- **GitHub Actions**: https://github.com/yunior123/origna_gta/actions
- **Firebase Console**: https://console.firebase.google.com/project/orignagta
- **Logs Functions**: `firebase functions:log --only <function_name>`

### ⚡ Déploiement Manuel (Si Besoin)

```bash
# Tout déployer manuellement
firebase deploy

# Déploiement sélectif
firebase deploy --only functions
firebase deploy --only hosting
firebase deploy --only firestore:rules
firebase deploy --only firestore:indexes
```

### 🛡️ Rollback en Cas d'Erreur

```bash
# Rollback functions
firebase functions:rollback <function_name> --revision <revision_id>

# Rollback hosting (via console Firebase)
# Firebase Console → Hosting → Rollback to previous version

# Rollback rules (revert via git)
git revert <commit_hash>
git push origin main  # Auto-redéploie les anciennes rules
```

### 🔧 Environnements

| Env | Branche | Auto-Deploy | URL |
|-----|---------|-------------|-----|
| Production | `main` | ✅ Oui | https://orignagta.web.app |
| Preview | PR branches | ✅ Oui | Généré par Firebase Hosting |

### 📈 Métriques de Déploiement

Le workflow génère automatiquement:
- ✅ Status de tous les tests
- ✅ Temps de build Flutter
- ✅ Taille du bundle web
- ✅ Logs de déploiement Firebase
- ✅ URLs de preview pour les PRs

---

## 🎉 Résultat

**Chaque `git push origin main` déploie automatiquement**:
1. ✅ L'app Flutter web (Hosting)
2. ✅ Toutes les Cloud Functions (Backend)
3. ✅ Les règles de sécurité Firestore
4. ✅ Les indexes de performance Firestore

**Durée estimée**: ~5-8 minutes par déploiement complet.

---

## ⚠️ Checklist Avant Premier Push

- [ ] Secret `FIREBASE_SERVICE_ACCOUNT` configuré dans GitHub
- [ ] Firebase CLI installé localement (`npm i -g firebase-tools`)
- [ ] Service account a les permissions nécessaires:
  - Cloud Functions Admin
  - Firebase Hosting Admin
  - Cloud Datastore User
- [ ] Tests locaux passent (`pytest` + `flutter test`)

Une fois ces points vérifiés, chaque push déclenchera automatiquement le déploiement complet ! 🚀
