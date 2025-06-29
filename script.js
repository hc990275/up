const init = () => {
    setDate();
    setupEventListeners();
};

const setDate = () => {
    const date = new Date();
    const options = { year: 'numeric', month: 'long', day: 'numeric' };
    document.getElementById('currentDate').innerText = date.toLocaleDateString('zh-CN', options);
};

const showSection = (sectionId) => {
    document.querySelectorAll('.section').forEach(section => {
        section.classList.remove('active');
        section.setAttribute('aria-hidden', 'true');
    });
    const activeSection = document.getElementById(sectionId);
    activeSection.classList.add('active');
    activeSection.setAttribute('aria-hidden', 'false');

    document.querySelectorAll('.selector button').forEach(btn => {
        btn.classList.remove('active');
        btn.removeAttribute('aria-current');
    });
    const activeButton = document.querySelector(`button[data-section="${sectionId}"]`);
    activeButton.classList.add('active');
    activeButton.setAttribute('aria-current', 'true');
};

const setupEventListeners = () => {
    document.querySelectorAll('.selector button').forEach(btn => {
        btn.addEventListener('click', () => showSection(btn.dataset.section));
    });
};

window.onload = init;