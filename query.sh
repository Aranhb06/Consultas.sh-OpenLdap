#!/bin/bash

# Message arrays for different languages
declare -A MSG

# Spanish messages
MSG[es,title]="Consulta de Directorio LDAP Local"
MSG[es,select_lang]="Seleccione el idioma / Select language / Sélectionnez la langue:"
MSG[es,lang_1]="1) Español"
MSG[es,lang_2]="2) English"
MSG[es,lang_3]="3) Français"
MSG[es,lang_4]="4) Salir/Exit/Quitter"
MSG[es,invalid_lang]="Selección inválida. Por favor, intente de nuevo."
MSG[es,admin_dn]="Introduce el DN de administrador (ej: cn=admin,dc=example,dc=com): "
MSG[es,base_dn]="Introduce el DN base de búsqueda (ej: dc=example,dc=com): "
MSG[es,password]="Introduce la contraseña LDAP: "
MSG[es,querying]="Realizando consulta LDAP en servidor local..."
MSG[es,ldap_structure]="=== Estructura LDAP ==="
MSG[es,group]="Grupo"
MSG[es,members]="Miembros"
MSG[es,error_prefix]="Error"
MSG[es,empty_admin_dn]="El DN de administrador no puede estar vacío"
MSG[es,empty_base_dn]="El DN base no puede estar vacío"
MSG[es,empty_password]="La contraseña no puede estar vacía"
MSG[es,ldapsearch_missing]="ldapsearch no está instalado. Por favor, instale ldap-utils"
MSG[es,final_message]="Pulsa [Enter] para cerrar el programa: "

# English messages
MSG[en,title]="Local LDAP Directory Query"
MSG[en,select_lang]="Seleccione el idioma / Select language / Sélectionnez la langue:"
MSG[en,lang_1]="1) Español"
MSG[en,lang_2]="2) English"
MSG[en,lang_3]="3) Français"
MSG[en,lang_4]="4) Salir/Exit/Quitter"
MSG[en,invalid_lang]="Invalid selection. Please try again."
MSG[en,admin_dn]="Enter admin DN (e.g., cn=admin,dc=example,dc=com): "
MSG[en,base_dn]="Enter base DN for search (e.g., dc=example,dc=com): "
MSG[en,password]="Enter LDAP password: "
MSG[en,querying]="Performing LDAP query on local server..."
MSG[en,ldap_structure]="=== LDAP Structure ==="
MSG[en,group]="Group"
MSG[en,members]="Members"
MSG[en,error_prefix]="Error"
MSG[en,empty_admin_dn]="Admin DN cannot be empty"
MSG[en,empty_base_dn]="Base DN cannot be empty"
MSG[en,empty_password]="Password cannot be empty"
MSG[en,ldapsearch_missing]="ldapsearch is not installed. Please install ldap-utils"
MSG[en,final_message]="Press [Enter] to close the program: "

# French messages
MSG[fr,title]="Requête d'Annuaire LDAP Local"
MSG[fr,select_lang]="Seleccione el idioma / Select language / Sélectionnez la langue:"
MSG[fr,lang_1]="1) Español"
MSG[fr,lang_2]="2) English"
MSG[fr,lang_3]="3) Français"
MSG[fr,lang_4]="4) Salir/Exit/Quitter"
MSG[fr,invalid_lang]="Sélection invalide. Veuillez réessayer."
MSG[fr,admin_dn]="Entrez le DN administrateur (ex: cn=admin,dc=example,dc=com): "
MSG[fr,base_dn]="Entrez le DN de base pour la recherche (ex: dc=example,dc=com): "
MSG[fr,password]="Entrez le mot de passe LDAP: "
MSG[fr,querying]="Exécution de la requête LDAP sur le serveur local..."
MSG[fr,ldap_structure]="=== Structure LDAP ==="
MSG[fr,group]="Groupe"
MSG[fr,members]="Membres"
MSG[fr,error_prefix]="Erreur"
MSG[fr,empty_admin_dn]="Le DN administrateur ne peut pas être vide"
MSG[fr,empty_base_dn]="Le DN de base ne peut pas être vide"
MSG[fr,empty_password]="Le mot de passe ne peut pas être vide"
MSG[fr,ldapsearch_missing]="ldapsearch n'est pas installé. Veuillez installer ldap-utils"
MSG[fr,final_message]="Appuyez sur [Entrée] pour fermer le programme: "

# Function to show error messages
mostrar_error() {
    echo -e "\e[31m${MSG[$LANG_CODE,error_prefix]}: $1\e[0m"
    exit 1
}

# Language selection
while true; do
    echo "${MSG[es,select_lang]}"
    echo "${MSG[es,lang_1]}"
    echo "${MSG[es,lang_2]}"
    echo "${MSG[es,lang_3]}"
    echo "${MSG[es,lang_4]}"
    read -p "> " lang_choice
    
    case $lang_choice in
        1) LANG_CODE="es"; break ;;
        2) LANG_CODE="en"; break ;;
        3) LANG_CODE="fr"; break ;;
        4) echo "Goodbye / Adiós / Au revoir"
        exit 0 ;;
        *) echo -e "\e[31m${MSG[es,invalid_lang]}\e[0m" ;;
    esac
done

# Check if ldapsearch is installed
command -v ldapsearch >/dev/null 2>&1 || mostrar_error "${MSG[$LANG_CODE,ldapsearch_missing]}"

# Banner
echo "==============================================="
echo "    ${MSG[$LANG_CODE,title]}"
echo "==============================================="
echo

# Request credentials
read -p "${MSG[$LANG_CODE,admin_dn]}" admin_dn
[ -z "$admin_dn" ] && mostrar_error "${MSG[$LANG_CODE,empty_admin_dn]}"

read -p "${MSG[$LANG_CODE,base_dn]}" base_dn
[ -z "$base_dn" ] && mostrar_error "${MSG[$LANG_CODE,empty_base_dn]}"

read -s -p "${MSG[$LANG_CODE,password]}" ldap_pass
echo
[ -z "$ldap_pass" ] && mostrar_error "${MSG[$LANG_CODE,empty_password]}"

echo -e "\n${MSG[$LANG_CODE,querying]}\n"

# Perform LDAP query
resultado=$(LDAPPASS="$ldap_pass" ldapsearch -x -H ldap://localhost -D "$admin_dn" -w "$ldap_pass" -b "$base_dn" -s sub "(objectClass=*)" 2>&1)

# Verify if there was an error in the query
if [ $? -ne 0 ]; then
    mostrar_error "$resultado"
fi

# Create temporary file
temp_file=$(mktemp)
echo "$resultado" > "$temp_file"

# Show results in tree format
echo "${MSG[$LANG_CODE,ldap_structure]}"
echo "└── $base_dn"

# Store users and their gidNumbers
declare -A usuarios_gid
while read -r line; do
    if [[ $line =~ ^dn:\ (.+) ]]; then
        dn="${BASH_REMATCH[1]}"
        entrada=$(sed -n "/^dn: $dn$/,/^$/p" "$temp_file")
        
        # If it's a user (has gidNumber and uid)
        if echo "$entrada" | grep -q "objectClass: posixAccount"; then
            uid=$(echo "$entrada" | grep "^uid: " | cut -d' ' -f2)
            gid=$(echo "$entrada" | grep "^gidNumber: " | cut -d' ' -f2)
            if [ ! -z "$uid" ] && [ ! -z "$gid" ]; then
                usuarios_gid[$gid]+="$uid "
            fi
        fi
    fi
done < <(grep "^dn:" "$temp_file")

# Process each DN entry to show the structure
while read -r line; do
    if [[ $line =~ ^dn:\ (.+) ]]; then
        dn="${BASH_REMATCH[1]}"
        nivel=$(($(echo "$dn" | tr -cd ',' | wc -c) - $(echo "$base_dn" | tr -cd ',' | wc -c)))
        prefijo=""
        for ((i=0; i<nivel; i++)); do
            prefijo="    $prefijo"
        done
        
        # Get complete entry
        entrada=$(sed -n "/^dn: $dn$/,/^$/p" "$temp_file")
        
        # Verify if it's a group
        if echo "$entrada" | grep -q "objectClass: posixGroup"; then
            echo "${prefijo}└── ${MSG[$LANG_CODE,group]}: ${dn%%,*}"
            # Get group's gidNumber
            gid=$(echo "$entrada" | grep "^gidNumber: " | cut -d' ' -f2)
            echo "${prefijo}    └── ${MSG[$LANG_CODE,members]}:"
            
            # Show users belonging to the group
            if [ ! -z "${usuarios_gid[$gid]}" ]; then
                for usuario in ${usuarios_gid[$gid]}; do
                    echo "${prefijo}        └── $usuario"
                done
            fi
        else
            echo "${prefijo}└── ${dn%%,*}"
        fi
    fi
done < <(grep "^dn:" "$temp_file")

# Clean up temporary file
rm -f "$temp_file"

echo ""
read -p "${MSG[$LANG_CODE,final_message]}"
