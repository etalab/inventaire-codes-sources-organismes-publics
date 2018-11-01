#!/bin/bash

########################################################################
# Initialize variables
#
champs_owner_json=".login,.html_url,.blog,.email,.bio,\
.public_repos,.followers,.created_at,.updated_at"

champs_owner_csv="Nom,URL,Blog,Email,Description,\
# dépôts,# followers,Créé,Mis à jour"

jq_owner_exp='[['$champs_owner_json']]'

champs_repo_json=".name,.owner.html_url,.html_url,.description,.fork,\
.created_at,.updated_at,.homepage,.stargazers_count,.forks_count,\
.license.name,.open_issues,.language"

champs_repo_csv="Nom,Organisation,URL,Description,Fork?,Créé,Mis à jour\
,Homepage,Stars,# forks,Licence,Issues,Langages"

jq_repo_exp='[.[] | ['$champs_repo_json']]'

credentials=$GITHUB_USER:$GITHUB_TOKEN

########################################################################
# Prepare repositories
#
rm -fr organisations repositories
mkdir organisations repositories
# Delete temporary files
mkdir -p tmp; rm tmp/* 2>/dev/null

########################################################################
# Collect french organisations as listed on
# https://government.github.com/community/
curl https://raw.githubusercontent.com/github/government.github.com/gh-pages/_data/governments.yml | yq .France[] | sed -e 's/^"//' -e 's/"$//' | sort -u > tmp/organismes_publics1.txt

# Add those listed on
# https://github.com/DISIC/politique-de-contribution-open-source, only
# if they are not already listed in the previous list (case
# insensitive comparison)
curl https://raw.githubusercontent.com/DISIC/politique-de-contribution-open-source/master/OrgAccounts | awk -F / '$3 == "github.com" {print $4}' | while read org; do
    grep -qi "^$org\$" tmp/organismes_publics1.txt || echo "$org"
done > tmp/organismes_publics2.txt

# Create the list
sort -u tmp/organismes_publics{1,2}.txt > organisations/organismes_publics.txt

# Read organisations/organismes_publics.txt and output owner info as csv
while read line; do
    curl -u $credentials -s https://api.github.com/users/$line \
	| jq "$jq_owner_exp" | jq -r '.[] | @csv' > tmp/$line.csv
done < organisations/organismes_publics.txt

# Concat owner information into organisations/comptes-organismes-publics.csv
echo $champs_owner_csv | cat - tmp/*.csv > organisations/comptes-organismes-publics.csv

# Delete temporary files
mkdir -p tmp; rm tmp/*

# Read organisations/organismes_publics.txt and output repositories as csv
while read line; do
    curl -u $credentials -s https://api.github.com/orgs/$line/repos?per_page=200 \
	| jq "$jq_repo_exp" | jq -r '.[] | @csv' > tmp/$line.csv
    cat tmp/$line.csv >> tmp/all_repositories.csv
    echo $champs_repo_csv | cat - tmp/$line.csv > repositories/$line.csv
done < organisations/organismes_publics.txt

# Add csv header to all_repositories.csv
echo $champs_repo_csv | cat - tmp/all_repositories.csv > repositories/all_repositories.csv

# Delete temporary files
rm -fr tmp
