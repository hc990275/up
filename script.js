const gameContainer = document.getElementById('game-container');
const scoreElement = document.getElementById('score');

let score = 0;

// 创建气球
function createBalloon() {
    const balloon = document.createElement('div');
    balloon.classList.add('balloon');

    // 设置随机位置
    balloon.style.left = `${Math.random() * 90}%`;
    balloon.style.animationDuration = `${Math.random() * 3 + 3}s`;

    // 点击气球得分
    balloon.addEventListener('click', () => {
        score++;
        scoreElement.textContent = score;
        balloon.remove(); // 移除点击的气球
    });

    gameContainer.appendChild(balloon);

    // 气球飞出屏幕时删除
    balloon.addEventListener('animationend', () => {
        balloon.remove();
    });
}

// 不断生成气球
setInterval(createBalloon, 1000);