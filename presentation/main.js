/* ============================================
   Smart Home IoT — 3D Presentation Engine
   Three.js Background + 3D House Scene + Slides
   ============================================ */

// ──── BACKGROUND PARTICLE SCENE ────
const bgCanvas = document.getElementById('bg-canvas');
const bgScene = new THREE.Scene();
const bgCamera = new THREE.PerspectiveCamera(75, window.innerWidth / window.innerHeight, 0.1, 1000);
const bgRenderer = new THREE.WebGLRenderer({ canvas: bgCanvas, alpha: true, antialias: true });
bgRenderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
bgRenderer.setSize(window.innerWidth, window.innerHeight);
bgCamera.position.z = 30;

// Particles
const PARTICLE_COUNT = 800;
const pGeo = new THREE.BufferGeometry();
const pPos = new Float32Array(PARTICLE_COUNT * 3);
const pVel = new Float32Array(PARTICLE_COUNT * 3);
for (let i = 0; i < PARTICLE_COUNT * 3; i += 3) {
  pPos[i]     = (Math.random() - 0.5) * 80;
  pPos[i + 1] = (Math.random() - 0.5) * 80;
  pPos[i + 2] = (Math.random() - 0.5) * 80;
  pVel[i]     = (Math.random() - 0.5) * 0.006;
  pVel[i + 1] = (Math.random() - 0.5) * 0.006;
  pVel[i + 2] = (Math.random() - 0.5) * 0.006;
}
pGeo.setAttribute('position', new THREE.BufferAttribute(pPos, 3));
const pMat = new THREE.PointsMaterial({ size: 0.06, color: 0x00e5ff, transparent: true, opacity: 0.5, blending: THREE.AdditiveBlending, sizeAttenuation: true });
const particlesMesh = new THREE.Points(pGeo, pMat);
bgScene.add(particlesMesh);

// Floating wireframe shapes
const floaters = [];
const geos = [new THREE.IcosahedronGeometry(1.2, 0), new THREE.TorusGeometry(1, 0.3, 16, 32), new THREE.OctahedronGeometry(1, 0)];
for (let i = 0; i < 4; i++) {
  const mat = new THREE.MeshBasicMaterial({ color: i % 2 === 0 ? 0x00e5ff : 0xa855f7, wireframe: true, transparent: true, opacity: 0.1 });
  const m = new THREE.Mesh(geos[i % geos.length], mat);
  m.position.set((Math.random() - 0.5) * 50, (Math.random() - 0.5) * 30, -15 + Math.random() * 10);
  m.userData = { rx: Math.random() * 0.003, ry: Math.random() * 0.003, baseY: m.position.y, fS: Math.random() * 0.0005 + 0.0003, fA: Math.random() * 3 + 1, mat };
  bgScene.add(m);
  floaters.push(m);
}

// ──── 3D HOUSE SCENE ────
const houseCanvas = document.getElementById('house-canvas');
const houseScene = new THREE.Scene();
const houseCamera = new THREE.PerspectiveCamera(50, 1, 0.1, 200);
const houseRenderer = new THREE.WebGLRenderer({ canvas: houseCanvas, alpha: true, antialias: true });
houseRenderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
houseRenderer.shadowMap.enabled = true;
houseRenderer.shadowMap.type = THREE.PCFSoftShadowMap;

// Lighting
const ambientLight = new THREE.AmbientLight(0x404060, 0.6);
houseScene.add(ambientLight);
const dirLight = new THREE.DirectionalLight(0xffffff, 0.9);
dirLight.position.set(8, 12, 10);
dirLight.castShadow = true;
dirLight.shadow.mapSize.width = 1024;
dirLight.shadow.mapSize.height = 1024;
houseScene.add(dirLight);
const fillLight = new THREE.DirectionalLight(0x4488ff, 0.3);
fillLight.position.set(-8, 5, -5);
houseScene.add(fillLight);
const rimLight = new THREE.PointLight(0x00e5ff, 0.4, 30);
rimLight.position.set(-5, 8, -8);
houseScene.add(rimLight);

// House group
const houseGroup = new THREE.Group();

// Ground
const groundGeo = new THREE.BoxGeometry(18, 0.3, 14);
const groundMat = new THREE.MeshPhongMaterial({ color: 0x1a2a1a, shininess: 10 });
const ground = new THREE.Mesh(groundGeo, groundMat);
ground.position.y = -2.65;
ground.receiveShadow = true;
houseGroup.add(ground);

// Grass patches
const grassMat = new THREE.MeshPhongMaterial({ color: 0x2d5a1e });
const grass1 = new THREE.Mesh(new THREE.BoxGeometry(16, 0.05, 12), grassMat);
grass1.position.y = -2.48;
houseGroup.add(grass1);

// House body
const bodyGeo = new THREE.BoxGeometry(7, 4.5, 6);
const bodyMat = new THREE.MeshPhongMaterial({ color: 0xd4c5a9, shininess: 20 });
const body = new THREE.Mesh(bodyGeo, bodyMat);
body.position.y = 0;
body.castShadow = true;
body.receiveShadow = true;
houseGroup.add(body);

// Roof — pyramid
const roofGeo = new THREE.ConeGeometry(5.8, 2.5, 4);
const roofMat = new THREE.MeshPhongMaterial({ color: 0x8b3a3a, shininess: 30 });
const roof = new THREE.Mesh(roofGeo, roofMat);
roof.position.y = 3.5;
roof.rotation.y = Math.PI / 4;
roof.castShadow = true;
houseGroup.add(roof);

// Door
const doorGeo = new THREE.BoxGeometry(1.2, 2.2, 0.15);
const doorMat = new THREE.MeshPhongMaterial({ color: 0x5a3825 });
const door = new THREE.Mesh(doorGeo, doorMat);
door.position.set(0, -1.1, 3.08);
houseGroup.add(door);

// Door handle
const handleGeo = new THREE.SphereGeometry(0.08, 8, 8);
const handleMat = new THREE.MeshPhongMaterial({ color: 0xccaa00, shininess: 80 });
const handle = new THREE.Mesh(handleGeo, handleMat);
handle.position.set(0.35, -1.1, 3.16);
houseGroup.add(handle);

// Windows with glow
const windowMat = new THREE.MeshPhongMaterial({ color: 0xffeebb, emissive: 0xffcc44, emissiveIntensity: 0.7, transparent: true, opacity: 0.9 });
const windowFrameMat = new THREE.MeshPhongMaterial({ color: 0x3a3a3a });

function createWindow(x, y, z, rotY) {
  const wGroup = new THREE.Group();
  // Glass
  const glass = new THREE.Mesh(new THREE.BoxGeometry(1.1, 1.1, 0.08), windowMat);
  wGroup.add(glass);
  // Frame cross
  const hBar = new THREE.Mesh(new THREE.BoxGeometry(1.2, 0.06, 0.12), windowFrameMat);
  wGroup.add(hBar);
  const vBar = new THREE.Mesh(new THREE.BoxGeometry(0.06, 1.2, 0.12), windowFrameMat);
  wGroup.add(vBar);
  // Window light glow
  const glowLight = new THREE.PointLight(0xffcc44, 0.3, 4);
  glowLight.position.set(0, 0, 0.5);
  wGroup.add(glowLight);

  wGroup.position.set(x, y, z);
  wGroup.rotation.y = rotY || 0;
  return wGroup;
}

// Front windows
houseGroup.add(createWindow(-2.2, 0.3, 3.08, 0));
houseGroup.add(createWindow(2.2, 0.3, 3.08, 0));
// Side windows
houseGroup.add(createWindow(3.55, 0.3, 0, Math.PI / 2));
houseGroup.add(createWindow(-3.55, 0.3, 0, Math.PI / 2));

// Chimney
const chimneyGeo = new THREE.BoxGeometry(0.8, 2, 0.8);
const chimneyMat = new THREE.MeshPhongMaterial({ color: 0x7a4a3a });
const chimney = new THREE.Mesh(chimneyGeo, chimneyMat);
chimney.position.set(2.2, 4, -1);
chimney.castShadow = true;
houseGroup.add(chimney);

// ── Phone model ──
const phoneGroup = new THREE.Group();
// Body
const phoneMat = new THREE.MeshPhongMaterial({ color: 0x1a1a2e, shininess: 60 });
const phoneBody = new THREE.Mesh(new THREE.BoxGeometry(1.6, 3, 0.15), phoneMat);
phoneBody.castShadow = true;
phoneGroup.add(phoneBody);
// Screen
const screenMat = new THREE.MeshPhongMaterial({ color: 0x111133, emissive: 0x1a3a6a, emissiveIntensity: 0.6 });
const screen = new THREE.Mesh(new THREE.BoxGeometry(1.35, 2.6, 0.02), screenMat);
screen.position.z = 0.085;
phoneGroup.add(screen);
// Screen app glow
const screenGlow = new THREE.PointLight(0x3b82f6, 0.5, 5);
screenGlow.position.set(0, 0, 0.5);
phoneGroup.add(screenGlow);
// Camera dot
const camDot = new THREE.Mesh(new THREE.SphereGeometry(0.06, 8, 8), new THREE.MeshPhongMaterial({ color: 0x333355 }));
camDot.position.set(0, 1.15, 0.085);
phoneGroup.add(camDot);

phoneGroup.position.set(6.5, 0.5, 2);
phoneGroup.rotation.y = -0.3;
phoneGroup.rotation.z = 0.1;

// ── Bluetooth wave particles ──
const BT_PARTICLE_COUNT = 60;
const btGeo = new THREE.BufferGeometry();
const btPos = new Float32Array(BT_PARTICLE_COUNT * 3);
const btData = [];
for (let i = 0; i < BT_PARTICLE_COUNT; i++) {
  btData.push({ t: Math.random(), speed: 0.003 + Math.random() * 0.006, offset: (Math.random() - 0.5) * 1.2 });
  btPos[i * 3] = 0; btPos[i * 3 + 1] = 0; btPos[i * 3 + 2] = 0;
}
btGeo.setAttribute('position', new THREE.BufferAttribute(btPos, 3));
const btMat = new THREE.PointsMaterial({ size: 0.12, color: 0x3b82f6, transparent: true, opacity: 0.8, blending: THREE.AdditiveBlending, sizeAttenuation: true });
const btParticles = new THREE.Points(btGeo, btMat);

// Bluetooth symbol floating between
const btSymbolGroup = new THREE.Group();
// Simple BT icon using lines
const btLineMat = new THREE.LineBasicMaterial({ color: 0x3b82f6, transparent: true, opacity: 0.9 });
const btShape = new THREE.BufferGeometry();
const btVerts = new Float32Array([
  0, -0.5, 0,   0.3, -0.2, 0,   0, 0.1, 0,   -0.3, -0.2, 0,   0, -0.5, 0,
  0, 0.5, 0,   -0.3, 0.2, 0,   0, -0.1, 0,   0.3, 0.2, 0,   0, 0.5, 0,
]);
btShape.setAttribute('position', new THREE.BufferAttribute(btVerts, 3));
const btIcon = new THREE.Line(btShape, btLineMat);
btIcon.scale.set(1.5, 1.5, 1.5);
btSymbolGroup.add(btIcon);
// Glow sphere around BT icon
const btGlow = new THREE.Mesh(
  new THREE.SphereGeometry(0.6, 16, 16),
  new THREE.MeshBasicMaterial({ color: 0x3b82f6, transparent: true, opacity: 0.08 })
);
btSymbolGroup.add(btGlow);
btSymbolGroup.position.set(3.2, 1.5, 2.5);

// Add everything to scene
houseScene.add(houseGroup);
houseScene.add(phoneGroup);
houseScene.add(btParticles);
houseScene.add(btSymbolGroup);

houseCamera.position.set(5, 5, 14);
houseCamera.lookAt(1.5, 0, 0);

// Resize house canvas
function resizeHouseCanvas() {
  const slide = houseCanvas.parentElement;
  if (!slide) return;
  const w = slide.clientWidth;
  const h = slide.clientHeight;
  houseRenderer.setSize(w, h);
  houseCamera.aspect = w / h;
  houseCamera.updateProjectionMatrix();
}
resizeHouseCanvas();

// ──── Mouse tracking ────
let mouseX = 0, mouseY = 0, tMouseX = 0, tMouseY = 0;
document.addEventListener('mousemove', (e) => {
  tMouseX = (e.clientX / window.innerWidth - 0.5) * 2;
  tMouseY = (e.clientY / window.innerHeight - 0.5) * 2;
});

// ──── Animation Loop ────
let time = 0;
const slideColors = [
  { primary: 0x00e5ff, secondary: 0xa855f7 },
  { primary: 0x3b82f6, secondary: 0x14b8a6 },
  { primary: 0xf59e0b, secondary: 0xec4899 },
  { primary: 0x54c5f8, secondary: 0x4ade80 },
];
let currentColorTarget = slideColors[0];

function animate() {
  requestAnimationFrame(animate);
  time += 0.001;
  mouseX += (tMouseX - mouseX) * 0.02;
  mouseY += (tMouseY - mouseY) * 0.02;

  // ── Background particles ──
  particlesMesh.rotation.y = time * 0.3 + mouseX * 0.1;
  particlesMesh.rotation.x = mouseY * 0.05;
  const pp = pGeo.attributes.position.array;
  for (let i = 0; i < PARTICLE_COUNT * 3; i += 3) {
    pp[i] += pVel[i]; pp[i+1] += pVel[i+1]; pp[i+2] += pVel[i+2];
    if (Math.abs(pp[i]) > 40) pVel[i] *= -1;
    if (Math.abs(pp[i+1]) > 40) pVel[i+1] *= -1;
    if (Math.abs(pp[i+2]) > 40) pVel[i+2] *= -1;
  }
  pGeo.attributes.position.needsUpdate = true;

  // Floaters
  floaters.forEach(o => {
    o.rotation.x += o.userData.rx;
    o.rotation.y += o.userData.ry;
    o.position.y = o.userData.baseY + Math.sin(time * 400 * o.userData.fS) * o.userData.fA;
  });

  // Color lerp
  const cpc = new THREE.Color(pMat.color);
  cpc.lerp(new THREE.Color(currentColorTarget.primary), 0.02);
  pMat.color = cpc;

  bgRenderer.render(bgScene, bgCamera);

  // ── 3D House scene (only render when slide 0 active) ──
  if (currentSlide === 0) {
    // Gentle house rotation with mouse influence
    houseGroup.rotation.y = Math.sin(time * 80) * 0.15 + mouseX * 0.2;
    houseGroup.rotation.x = mouseY * 0.05;

    // Phone gentle float
    phoneGroup.position.y = 0.5 + Math.sin(time * 500) * 0.3;
    phoneGroup.rotation.z = 0.1 + Math.sin(time * 300) * 0.03;

    // BT symbol pulse and float
    const btScale = 1 + Math.sin(time * 600) * 0.15;
    btSymbolGroup.scale.set(btScale, btScale, btScale);
    btSymbolGroup.position.y = 1.5 + Math.sin(time * 400) * 0.3;
    btSymbolGroup.rotation.y += 0.008;

    // BT particles flowing from house to phone
    const btPositions = btGeo.attributes.position.array;
    const startPos = { x: 2.5, y: 1, z: 2.5 };  // near house
    const endPos = { x: 6.5, y: 0.5, z: 2 };     // near phone
    for (let i = 0; i < BT_PARTICLE_COUNT; i++) {
      const d = btData[i];
      d.t += d.speed;
      if (d.t > 1) d.t -= 1;
      const t = d.t;
      btPositions[i * 3]     = startPos.x + (endPos.x - startPos.x) * t + Math.sin(t * Math.PI * 3 + d.offset) * 0.3;
      btPositions[i * 3 + 1] = startPos.y + (endPos.y - startPos.y) * t + Math.sin(t * Math.PI * 2) * 0.5 + d.offset * 0.3;
      btPositions[i * 3 + 2] = startPos.z + (endPos.z - startPos.z) * t + Math.cos(t * Math.PI * 3 + d.offset) * 0.2;
    }
    btGeo.attributes.position.needsUpdate = true;

    // Window glow flicker
    windowMat.emissiveIntensity = 0.6 + Math.sin(time * 800) * 0.1;

    houseRenderer.render(houseScene, houseCamera);
  }
}
animate();

// ──── Resize ────
window.addEventListener('resize', () => {
  bgCamera.aspect = window.innerWidth / window.innerHeight;
  bgCamera.updateProjectionMatrix();
  bgRenderer.setSize(window.innerWidth, window.innerHeight);
  resizeHouseCanvas();
});


// ──── SLIDE NAVIGATION ────
const slides = document.querySelectorAll('.slide');
const totalSlides = slides.length;
let currentSlide = 0;
let isTransitioning = false;

const slideCounter = document.getElementById('slideCounter');
const navDotsContainer = document.getElementById('navDots');
const prevBtn = document.getElementById('prevBtn');
const nextBtn = document.getElementById('nextBtn');

for (let i = 0; i < totalSlides; i++) {
  const dot = document.createElement('div');
  dot.className = 'nav-dot' + (i === 0 ? ' active' : '');
  dot.addEventListener('click', () => goToSlide(i));
  navDotsContainer.appendChild(dot);
}

function updateUI() {
  const num = String(currentSlide + 1).padStart(2, '0');
  const total = String(totalSlides).padStart(2, '0');
  slideCounter.textContent = `${num} / ${total}`;

  const dots = navDotsContainer.querySelectorAll('.nav-dot');
  dots.forEach((d, i) => d.classList.toggle('active', i === currentSlide));

  prevBtn.style.opacity = currentSlide === 0 ? '0.3' : '1';
  prevBtn.style.pointerEvents = currentSlide === 0 ? 'none' : 'auto';
  nextBtn.style.opacity = currentSlide === totalSlides - 1 ? '0.3' : '1';
  nextBtn.style.pointerEvents = currentSlide === totalSlides - 1 ? 'none' : 'auto';

  currentColorTarget = slideColors[currentSlide] || slideColors[0];
}

function goToSlide(index) {
  if (index === currentSlide || isTransitioning || index < 0 || index >= totalSlides) return;
  isTransitioning = true;

  const direction = index > currentSlide ? 1 : -1;
  const currentEl = slides[currentSlide];
  const nextEl = slides[index];

  currentEl.classList.remove('active');
  currentEl.classList.add(direction > 0 ? 'exit-left' : '');
  if (direction < 0) currentEl.style.transform = 'translateX(80px) rotateY(-5deg) scale(0.95)';

  if (direction > 0) {
    nextEl.style.transform = 'translateX(80px) rotateY(-5deg) scale(0.95)';
  } else {
    nextEl.style.transform = 'translateX(-80px) rotateY(5deg) scale(0.95)';
    nextEl.classList.remove('exit-left');
  }

  void nextEl.offsetWidth;
  nextEl.classList.add('active');
  nextEl.style.transform = '';

  currentSlide = index;
  updateUI();

  setTimeout(() => {
    currentEl.classList.remove('exit-left');
    currentEl.style.transform = '';
    isTransitioning = false;
  }, 800);
}

function nextSlide() { goToSlide(currentSlide + 1); }
function prevSlide() { goToSlide(currentSlide - 1); }

prevBtn.addEventListener('click', prevSlide);
nextBtn.addEventListener('click', nextSlide);

document.addEventListener('keydown', (e) => {
  if (e.key === 'ArrowRight' || e.key === 'ArrowDown' || e.key === ' ') { e.preventDefault(); nextSlide(); }
  else if (e.key === 'ArrowLeft' || e.key === 'ArrowUp') { e.preventDefault(); prevSlide(); }
});

let scrollCD = false;
document.addEventListener('wheel', (e) => {
  if (scrollCD) return; scrollCD = true;
  if (e.deltaY > 30) nextSlide(); else if (e.deltaY < -30) prevSlide();
  setTimeout(() => { scrollCD = false; }, 1000);
}, { passive: true });

let tStartX = 0, tStartY = 0;
document.addEventListener('touchstart', (e) => { tStartX = e.changedTouches[0].screenX; tStartY = e.changedTouches[0].screenY; }, { passive: true });
document.addEventListener('touchend', (e) => {
  const dx = e.changedTouches[0].screenX - tStartX;
  const dy = e.changedTouches[0].screenY - tStartY;
  if (Math.abs(dx) > Math.abs(dy) && Math.abs(dx) > 60) { dx < 0 ? nextSlide() : prevSlide(); }
}, { passive: true });

updateUI();
