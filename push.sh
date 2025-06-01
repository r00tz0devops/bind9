git add  .
#git commit -m "add Howto Folder"
git commit -m "Update: $(git diff --cached --name-only | paste -sd ',' -)"
git branch -M  main
git push -u origin main
