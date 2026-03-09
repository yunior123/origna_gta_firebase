#!/usr/bin/env python3
"""
Script pour remplacer l'initialisation globale de Firestore par lazy loading.
"""

import re


def fix_firestore_init(file_path: str) -> bool:
    """
    Remplace l'initialisation globale de Firestore par lazy loading.

    Args:
        file_path: Chemin du fichier à modifier

    Returns:
        True si le fichier a été modifié, False sinon
    """
    try:
        with open(file_path, encoding="utf-8") as f:
            content = f.read()

        # Vérifier si le fichier a déjà été corrigé
        if "def get_db():" in content:
            print(f"✓ {file_path} déjà corrigé")
            return False

        # Vérifier si le fichier a db = firestore.client()
        if "db = firestore.client()" not in content:
            print(f"⚠ {file_path} n'a pas d'initialisation globale")
            return False

        # Remplacer db = firestore.client() par la fonction get_db()
        old_pattern = r"^db = firestore\.client\(\)$"
        new_code = '''_db = None

def get_db():
    """Get Firestore client (lazy initialization)."""
    global _db
    if _db is None:
        _db = firestore.client()
    return _db'''

        content = re.sub(old_pattern, new_code, content, flags=re.MULTILINE)

        # Remplacer toutes les occurrences de db. par get_db().
        # Mais attention à ne pas remplacer dans les commentaires ou strings
        # On utilise un regex qui évite les commentaires

        # Pattern plus prudent: remplacer db. uniquement quand c'est un appel de méthode
        # et pas dans une string ou un commentaire
        lines = content.split("\n")
        new_lines = []

        for line in lines:
            # Ignorer les lignes de commentaires
            if line.strip().startswith("#"):
                new_lines.append(line)
                continue

            # Ignorer les lignes qui sont dans des strings (approximation)
            # Chercher db. mais pas dans les strings
            if "db." in line and not line.strip().startswith('"""') and not line.strip().startswith("'''"):
                # Vérifier si c'est dans une partie de code (pas dans un string)
                # Simple heuristique: si la ligne a des quotes, on la traite avec précaution
                if '"' in line or "'" in line:
                    # Plus complexe, on doit parser les strings
                    # Pour l'instant, on fait un remplacement simple
                    # en évitant les strings entre quotes
                    parts = []
                    in_string = False
                    quote_char = None
                    i = 0
                    while i < len(line):
                        if not in_string and (line[i] == '"' or line[i] == "'"):
                            in_string = True
                            quote_char = line[i]
                            parts.append(line[i])
                            i += 1
                        elif in_string and line[i] == quote_char and (i == 0 or line[i - 1] != "\\"):
                            in_string = False
                            quote_char = None
                            parts.append(line[i])
                            i += 1
                        elif not in_string and i + 2 < len(line) and line[i : i + 3] == "db.":
                            parts.append("get_db().")
                            i += 3
                        else:
                            parts.append(line[i])
                            i += 1
                    line = "".join(parts)
                else:
                    # Pas de strings, remplacement simple
                    line = line.replace("db.", "get_db().")

            new_lines.append(line)

        content = "\n".join(new_lines)

        # Écrire le fichier modifié
        with open(file_path, "w", encoding="utf-8") as f:
            f.write(content)

        print(f"✓ {file_path} modifié avec succès")
        return True

    except Exception as e:
        print(f"✗ Erreur lors du traitement de {file_path}: {e}")
        return False


if __name__ == "__main__":
    files_to_fix = [
        "handlers/payment_stripe.py",
        "handlers/orders.py",
        "handlers/admin.py",
        "handlers/cron_jobs.py",
        "handlers/products.py",
    ]

    fixed_count = 0
    for file in files_to_fix:
        if fix_firestore_init(file):
            fixed_count += 1

    print(f"\n{fixed_count} fichier(s) modifié(s)")
