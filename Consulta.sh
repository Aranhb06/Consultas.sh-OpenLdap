#!/bin/bash

# Función para mostrar mensajes de error
mostrar_error() {
    echo -e "\e[31mError: $1\e[0m"
    exit 1
}

# Comprobar si ldapsearch está instalado
command -v ldapsearch >/dev/null 2>&1 || mostrar_error "ldapsearch no está instalado. Por favor, instale ldap-utils"

# Banner
echo "==============================================="
echo "    Consulta de Directorio LDAP Local"
echo "==============================================="
echo

# Solicitar credenciales
read -p "Introduce el DN de administrador (ej: cn=admin,dc=example,dc=com): " admin_dn
[ -z "$admin_dn" ] && mostrar_error "El DN de administrador no puede estar vacío"

read -p "Introduce el DN base de búsqueda (ej: dc=example,dc=com): " base_dn
[ -z "$base_dn" ] && mostrar_error "El DN base no puede estar vacío"

read -s -p "Introduce la contraseña LDAP: " ldap_pass
echo
[ -z "$ldap_pass" ] && mostrar_error "La contraseña no puede estar vacía"

echo -e "\nRealizando consulta LDAP en servidor local...\n"

# Realizar consulta LDAP
resultado=$(LDAPPASS="$ldap_pass" ldapsearch -x -H ldap://localhost -D "$admin_dn" -w "$ldap_pass" -b "$base_dn" -s sub "(objectClass=*)" 2>&1)

# Verificar si hay error en la consulta
if [ $? -ne 0 ]; then
    mostrar_error "Error al realizar la consulta LDAP:\n$resultado"
fi

# Crear archivo temporal
temp_file=$(mktemp)
echo "$resultado" > "$temp_file"

# Mostrar resultados en formato árbol
echo "=== Estructura LDAP ==="
echo "└── $base_dn"

# Almacenar usuarios y sus gidNumbers
declare -A usuarios_gid
while read -r line; do
    if [[ $line =~ ^dn:\ (.+) ]]; then
        dn="${BASH_REMATCH[1]}"
        entrada=$(sed -n "/^dn: $dn$/,/^$/p" "$temp_file")
        
        # Si es un usuario (tiene gidNumber y uid)
        if echo "$entrada" | grep -q "objectClass: posixAccount"; then
            uid=$(echo "$entrada" | grep "^uid: " | cut -d' ' -f2)
            gid=$(echo "$entrada" | grep "^gidNumber: " | cut -d' ' -f2)
            if [ ! -z "$uid" ] && [ ! -z "$gid" ]; then
                usuarios_gid[$gid]+="$uid "
            fi
        fi
    fi
done < <(grep "^dn:" "$temp_file")

# Procesar cada entrada DN para mostrar la estructura
while read -r line; do
    if [[ $line =~ ^dn:\ (.+) ]]; then
        dn="${BASH_REMATCH[1]}"
        nivel=$(($(echo "$dn" | tr -cd ',' | wc -c) - $(echo "$base_dn" | tr -cd ',' | wc -c)))
        prefijo=""
        for ((i=0; i<nivel; i++)); do
            prefijo="    $prefijo"
        done
        
        # Obtener la entrada completa
        entrada=$(sed -n "/^dn: $dn$/,/^$/p" "$temp_file")
        
        # Verificar si es un grupo
        if echo "$entrada" | grep -q "objectClass: posixGroup"; then
            echo "${prefijo}└── Grupo: ${dn%%,*}"
            # Obtener gidNumber del grupo
            gid=$(echo "$entrada" | grep "^gidNumber: " | cut -d' ' -f2)
            echo "${prefijo}    └── Miembros:"
            
            # Mostrar usuarios que pertenecen al grupo
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

# Limpiar archivo temporal
rm -f "$temp_file"
