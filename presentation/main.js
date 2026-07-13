/* ============================================
   Smart Home IoT — 3D Presentation Engine
   Top-Down House Floor Plan + Particle BG
   ============================================ */

// ──── BACKGROUND PARTICLE SCENE ────
const bgCanvas = document.getElementById('bg-canvas');
const bgScene = new THREE.Scene();
const bgCamera = new THREE.PerspectiveCamera(75, window.innerWidth / window.innerHeight, 0.1, 1000);
const bgRenderer = new THREE.WebGLRenderer({ canvas: bgCanvas, alpha: true, antialias: true });
bgRenderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
bgRenderer.setSize(window.innerWidth, window.innerHeight);
bgCamera.position.z = 30;

const PARTICLE_COUNT = 600;
const pGeo = new THREE.BufferGeometry();
const pPos = new Float32Array(PARTICLE_COUNT * 3);
const pVel = new Float32Array(PARTICLE_COUNT * 3);
for (let i = 0; i < PARTICLE_COUNT * 3; i += 3) {
  pPos[i] = (Math.random() - 0.5) * 80;
  pPos[i+1] = (Math.random() - 0.5) * 80;
  pPos[i+2] = (Math.random() - 0.5) * 80;
  pVel[i] = (Math.random() - 0.5) * 0.005;
  pVel[i+1] = (Math.random() - 0.5) * 0.005;
  pVel[i+2] = (Math.random() - 0.5) * 0.005;
}
pGeo.setAttribute('position', new THREE.BufferAttribute(pPos, 3));
const pMat = new THREE.PointsMaterial({ size: 0.06, color: 0x00e5ff, transparent: true, opacity: 0.4, blending: THREE.AdditiveBlending, sizeAttenuation: true });
const particlesMesh = new THREE.Points(pGeo, pMat);
bgScene.add(particlesMesh);

// ──── 3D HOUSE TOP-DOWN SCENE ────
const houseCanvas = document.getElementById('house-canvas');
let houseScene, houseCamera, houseRenderer;
let houseGroup;
const ledMeshes = [];
const ledLights = [];
let pirMesh, ldrMesh, buzMesh;

if (houseCanvas) {
  houseScene = new THREE.Scene();
  houseScene.fog = new THREE.FogExp2(0x0a0e1a, 0.012);

  // Orthographic-like perspective from above with slight angle
  houseCamera = new THREE.PerspectiveCamera(45, 1, 0.1, 200);
  houseCamera.position.set(0, 22, 6);
  houseCamera.lookAt(0, 0, 0);

  houseRenderer = new THREE.WebGLRenderer({ canvas: houseCanvas, alpha: true, antialias: true });
  houseRenderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));

  // Lighting
  const ambient = new THREE.AmbientLight(0x334466, 0.8);
  houseScene.add(ambient);
  const dirLight = new THREE.DirectionalLight(0xffffff, 0.5);
  dirLight.position.set(5, 20, 5);
  houseScene.add(dirLight);

  // ── Build the floor plan ──
  houseGroup = new THREE.Group();

  // Room floor colors (subtle dark tones)
  const roomColors = [0x1a2533, 0x1a2830, 0x1f2533, 0x1a2530];
  const roomLabels = ['Room 1', 'Room 2', 'Room 3', 'Room 4'];

  // Room positions: 2x2 grid, each room 5x5 units
  // Room 1: top-left, Room 2: top-right, Room 3: bottom-left, Room 4: bottom-right
  const roomCenters = [
    { x: -2.8, z: -2.8 }, // Room 1
    { x:  2.8, z: -2.8 }, // Room 2
    { x: -2.8, z:  2.8 }, // Room 3
    { x:  2.8, z:  2.8 }, // Room 4
  ];
  const ROOM_SIZE = 5;
  const WALL_H = 1.2;
  const WALL_T = 0.18;

  // Floor per room
  roomCenters.forEach((rc, i) => {
    const floor = new THREE.Mesh(
      new THREE.BoxGeometry(ROOM_SIZE - 0.2, 0.1, ROOM_SIZE - 0.2),
      new THREE.MeshPhongMaterial({ color: roomColors[i], shininess: 5 })
    );
    floor.position.set(rc.x, 0, rc.z);
    houseGroup.add(floor);
  });

  // Wall material
  const wallMat = new THREE.MeshPhongMaterial({ color: 0x556677, shininess: 15, transparent: true, opacity: 0.85 });

  function addWall(x, z, w, d) {
    const wall = new THREE.Mesh(new THREE.BoxGeometry(w, WALL_H, d), wallMat);
    wall.position.set(x, WALL_H / 2, z);
    houseGroup.add(wall);
  }

  // Outer walls
  const HS = 5.4; // half-size
  addWall(0, -HS, HS * 2 + WALL_T, WALL_T);   // top
  addWall(0, HS, HS * 2 + WALL_T, WALL_T);     // bottom
  addWall(-HS, 0, WALL_T, HS * 2 + WALL_T);    // left
  addWall(HS, 0, WALL_T, HS * 2 + WALL_T);     // right

  // Inner walls with door gaps
  // Horizontal center wall (gap in the middle for hallway)
  addWall(-3.2, 0, 4.4, WALL_T);   // left part
  addWall(3.2, 0, 4.4, WALL_T);    // right part

  // Vertical center wall (gap in the middle for hallway)
  addWall(0, -3.2, WALL_T, 4.4);   // top part
  addWall(0, 3.2, WALL_T, 4.4);    // bottom part

  // ── LEDs: 2 per room (yellow glowing spheres) ──
  const ledPositions = [
    // Room 1
    { x: -3.8, z: -3.8 }, { x: -1.8, z: -1.8 },
    // Room 2
    { x: 1.8, z: -3.8 },  { x: 3.8, z: -1.8 },
    // Room 3
    { x: -3.8, z: 1.8 },  { x: -1.8, z: 3.8 },
    // Room 4
    { x: 1.8, z: 1.8 },   { x: 3.8, z: 3.8 },
  ];

  const ledGeo = new THREE.SphereGeometry(0.22, 12, 12);
  const ledMat = new THREE.MeshBasicMaterial({ color: 0xffcc44 });

  ledPositions.forEach((lp) => {
    const led = new THREE.Mesh(ledGeo, ledMat.clone());
    led.position.set(lp.x, 0.4, lp.z);
    houseGroup.add(led);
    ledMeshes.push(led);

    const light = new THREE.PointLight(0xffcc44, 0.4, 3);
    light.position.set(lp.x, 0.6, lp.z);
    houseGroup.add(light);
    ledLights.push(light);
  });

  // ── PIR Motion Sensor (red cone, center-top area) ──
  const pirGeo = new THREE.ConeGeometry(0.3, 0.5, 8);
  const pirMat = new THREE.MeshPhongMaterial({ color: 0xff4466, emissive: 0xff2244, emissiveIntensity: 0.4 });
  pirMesh = new THREE.Mesh(pirGeo, pirMat);
  pirMesh.position.set(0, 0.5, -4.8);
  pirMesh.rotation.x = Math.PI; // upside down cone
  houseGroup.add(pirMesh);
  const pirLight = new THREE.PointLight(0xff4466, 0.3, 4);
  pirLight.position.set(0, 0.8, -4.8);
  houseGroup.add(pirLight);

  // ── LDR Light Sensor (green sphere, near outer wall) ──
  const ldrGeo = new THREE.SphereGeometry(0.25, 12, 12);
  const ldrMat = new THREE.MeshPhongMaterial({ color: 0x44ff88, emissive: 0x22ff66, emissiveIntensity: 0.4 });
  ldrMesh = new THREE.Mesh(ldrGeo, ldrMat);
  ldrMesh.position.set(-4.8, 0.4, 0);
  houseGroup.add(ldrMesh);
  const ldrLight = new THREE.PointLight(0x44ff88, 0.3, 4);
  ldrLight.position.set(-4.8, 0.6, 0);
  houseGroup.add(ldrLight);

  // ── Buzzer (purple octahedron, near entrance) ──
  const buzGeo = new THREE.OctahedronGeometry(0.28, 0);
  const buzMat = new THREE.MeshPhongMaterial({ color: 0xaa66ff, emissive: 0x8844dd, emissiveIntensity: 0.4 });
  buzMesh = new THREE.Mesh(buzGeo, buzMat);
  buzMesh.position.set(4.8, 0.45, 0);
  houseGroup.add(buzMesh);
  const buzLight = new THREE.PointLight(0xaa66ff, 0.3, 4);
  buzLight.position.set(4.8, 0.6, 0);
  houseGroup.add(buzLight);

  // ── Room labels using sprite textures ──
  function createLabel(text, x, z, color) {
    const canvas2d = document.createElement('canvas');
    canvas2d.width = 256;
    canvas2d.height = 64;
    const ctx = canvas2d.getContext('2d');
    ctx.font = 'bold 28px Outfit, sans-serif';
    ctx.fillStyle = color || '#ffffff';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(text, 128, 32);

    const tex = new THREE.CanvasTexture(canvas2d);
    const spriteMat = new THREE.SpriteMaterial({ map: tex, transparent: true, opacity: 0.7 });
    const sprite = new THREE.Sprite(spriteMat);
    sprite.position.set(x, 0.8, z);
    sprite.scale.set(2.5, 0.65, 1);
    houseGroup.add(sprite);
  }

  createLabel('Room 1', -2.8, -2.8, '#6ec6ff');
  createLabel('Room 2', 2.8, -2.8, '#6ec6ff');
  createLabel('Room 3', -2.8, 2.8, '#6ec6ff');
  createLabel('Room 4', 2.8, 2.8, '#6ec6ff');

  // LED labels (small "LED" tags)
  function createSmallLabel(text, x, z, color) {
    const c = document.createElement('canvas');
    c.width = 128; c.height = 40;
    const ctx = c.getContext('2d');
    ctx.font = 'bold 18px Outfit, sans-serif';
    ctx.fillStyle = color || '#ffcc44';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(text, 64, 20);
    const tex = new THREE.CanvasTexture(c);
    const mat = new THREE.SpriteMaterial({ map: tex, transparent: true, opacity: 0.6 });
    const s = new THREE.Sprite(mat);
    s.position.set(x, 1.1, z);
    s.scale.set(1.2, 0.4, 1);
    houseGroup.add(s);
  }

  // Label each LED
  for (let i = 0; i < 8; i++) {
    const room = Math.floor(i / 2) + 1;
    const ledNum = (i % 2) + 1;
    createSmallLabel(`LED ${ledNum}`, ledPositions[i].x, ledPositions[i].z, '#ffdd66');
  }

  // Label sensors
  createSmallLabel('PIR', 0, -4.8, '#ff6688');
  createSmallLabel('LDR', -4.8, 0, '#66ffaa');
  createSmallLabel('Buzzer', 4.8, 0, '#bb88ff');

  houseScene.add(houseGroup);
}

// ── Resize house canvas ──
function resizeHouseCanvas() {
  if (!houseCanvas || !houseRenderer) return;
  const container = houseCanvas.parentElement;
  if (!container) return;
  const w = container.clientWidth;
  const h = container.clientHeight;
  houseRenderer.setSize(w, h);
  houseCamera.aspect = w / h;
  houseCamera.updateProjectionMatrix();
}
resizeHouseCanvas();

// ──── Mouse ────
let mouseX = 0, mouseY = 0, tMouseX = 0, tMouseY = 0;
document.addEventListener('mousemove', (e) => {
  tMouseX = (e.clientX / window.innerWidth - 0.5) * 2;
  tMouseY = (e.clientY / window.innerHeight - 0.5) * 2;
});

// ──── ANIMATION ────
let time = 0;
let currentSlide = 0;
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

  // Background particles
  particlesMesh.rotation.y = time * 0.25 + mouseX * 0.08;
  particlesMesh.rotation.x = mouseY * 0.04;
  const pp = pGeo.attributes.position.array;
  for (let i = 0; i < PARTICLE_COUNT * 3; i += 3) {
    pp[i] += pVel[i]; pp[i+1] += pVel[i+1]; pp[i+2] += pVel[i+2];
    if (Math.abs(pp[i]) > 40) pVel[i] *= -1;
    if (Math.abs(pp[i+1]) > 40) pVel[i+1] *= -1;
    if (Math.abs(pp[i+2]) > 40) pVel[i+2] *= -1;
  }
  pGeo.attributes.position.needsUpdate = true;

  // Color lerp
  const c = new THREE.Color(pMat.color);
  c.lerp(new THREE.Color(currentColorTarget.primary), 0.02);
  pMat.color = c;

  bgRenderer.render(bgScene, bgCamera);

  // House scene (slide 0 only)
  if (currentSlide === 0 && houseRenderer) {
    // Gentle tilt with mouse
    houseGroup.rotation.y = mouseX * 0.15;
    houseGroup.rotation.x = mouseY * 0.05;

    // LED pulse glow
    const pulse = 0.6 + Math.sin(time * 600) * 0.35;
    ledMeshes.forEach((led) => {
      led.material.opacity = pulse;
    });
    ledLights.forEach((l) => {
      l.intensity = 0.2 + Math.sin(time * 600) * 0.2;
    });

    // PIR sensor rotation
    if (pirMesh) pirMesh.rotation.y += 0.015;
    // Buzzer rotation
    if (buzMesh) buzMesh.rotation.y += 0.01;
    // LDR gentle scale pulse
    if (ldrMesh) {
      const s = 1 + Math.sin(time * 400) * 0.15;
      ldrMesh.scale.set(s, s, s);
    }

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

let tStartX = 0;
document.addEventListener('touchstart', (e) => { tStartX = e.changedTouches[0].screenX; }, { passive: true });
document.addEventListener('touchend', (e) => {
  const dx = e.changedTouches[0].screenX - tStartX;
  if (Math.abs(dx) > 60) { dx < 0 ? nextSlide() : prevSlide(); }
}, { passive: true });

updateUI();
