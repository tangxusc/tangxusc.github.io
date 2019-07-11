echo '开始执行发布'
echo '步骤如下:'
echo '0,git status'
echo '1,git add .'
echo '2,git commit -e'
echo '3,git checkout master'
echo '4,git merge origin'
echo '5,hugo'
echo '6,git add .'
echo '7,git commit'
echo '8,git push origin master:master'
echo '9,git push origin origin:origin'
echo '-------------------------------'

sleep 5s
echo '-------------------------------'
echo '0,git status'
git checkout origin
git status
sleep 2s
echo '-------------------------------'
echo '1,git add .'
git add .
sleep 2s
echo '-------------------------------'
echo '2,git commit -e'
git commit -e
sleep 2s
echo '-------------------------------'
echo '3,git checkout master'
git checkout master
sleep 2s
echo '-------------------------------'
echo '4,git merge origin'
git merge origin
sleep 2s
echo '-------------------------------'
echo '5,hugo'
hugo
sleep 2s
echo '-------------------------------'
echo '6,git add .'
git add .
sleep 2s
echo '-------------------------------'
echo '7,git commit'
git commit
sleep 2s
echo '-------------------------------'
echo '8,git push origin master:master'
git push origin master:master
sleep 2s
echo '-------------------------------'
echo '9,git push origin origin:origin'
git push origin origin:origin
sleep 2s
echo '部署完成...'