/* ============================================
   Smart Home IoT — 3D Presentation Engine
   Light Mode — Top-Down House + Slide Nav
   ============================================ */

// ──── 3D HOUSE TOP-DOWN SCENE ────
const houseCanvas = document.getElementById('house-canvas');
let houseScene, houseCamera, houseRenderer;
let houseGroup;
const ledMeshes = [];
const ledLights = [];
let pirMesh, ldrMesh, buzMesh;
let currentSlide = 0;

if (houseCanvas) {
  houseScene = new THREE.Scene();
  houseScene.background = new THREE.Color(0xedf2f7);

  houseCamera = new THREE.PerspectiveCamera(45, 1, 0.1, 200);
  houseCamera.position.set(0, 22, 6);
  houseCamera.lookAt(0, 0, 0);

  houseRenderer = new THREE.WebGLRenderer({ canvas: houseCanvas, antialias: true });
  houseRenderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));

  // Lighting — bright and clean
  houseScene.add(new THREE.AmbientLight(0xffffff, 0.7));
  const dirLight = new THREE.DirectionalLight(0xffffff, 0.6);
  dirLight.position.set(6, 20, 8);
  houseScene.add(dirLight);
  const fillLight = new THREE.DirectionalLight(0x8899bb, 0.3);
  fillLight.position.set(-6, 15, -5);
  houseScene.add(fillLight);

  houseGroup = new THREE.Group();

  // ── Single open-plan rectangle ──
  const WALL_H = 1.0;
  const WALL_T = 0.15;
  const HW = 7;  // half-width
  const HD = 5;  // half-depth

  // Single floor
  const floor = new THREE.Mesh(
    new THREE.BoxGeometry(HW * 2 - 0.2, 0.08, HD * 2 - 0.2),
    new THREE.MeshPhongMaterial({ color: 0xe2e8f0, shininess: 10 })
  );
  floor.position.set(0, 0, 0);
  houseGroup.add(floor);

  // Walls — outer only
  const wallMat = new THREE.MeshPhongMaterial({ color: 0x94a3b8, shininess: 20 });
  function addWall(x, z, w, d) {
    const wall = new THREE.Mesh(new THREE.BoxGeometry(w, WALL_H, d), wallMat);
    wall.position.set(x, WALL_H / 2, z);
    houseGroup.add(wall);
  }
  addWall(0, -HD, HW * 2 + WALL_T, WALL_T);  // top
  addWall(0, HD, HW * 2 + WALL_T, WALL_T);   // bottom
  addWall(-HW, 0, WALL_T, HD * 2 + WALL_T);  // left
  addWall(HW, 0, WALL_T, HD * 2 + WALL_T);   // right

  // ── LEDs positioned to match physical layout ──
  // User's layout (index 0-7 = LED 1-8):
  //   LED3(idx2)---LED6(idx5)---LED4(idx3)   <- top
  //   LED1(idx0)               LED7(idx6)    <- middle
  //   LED5(idx4)---LED2(idx1)---LED8(idx7)   <- bottom
  const W = HW - 0.8;
  const D = HD - 0.8;
  const ledPositions = [
    { x: -W, z:  0   },  // LED1 — left center
    { x:  0, z:  D   },  // LED2 — bottom center
    { x: -W, z: -D   },  // LED3 — top-left corner
    { x:  W, z: -D   },  // LED4 — top-right corner
    { x: -W, z:  D   },  // LED5 — bottom-left corner
    { x:  0, z: -D   },  // LED6 — top center
    { x:  W, z:  0   },  // LED7 — right center
    { x:  W, z:  D   },  // LED8 — bottom-right corner
  ];

  const ledGeo = new THREE.SphereGeometry(0.25, 12, 12);
  ledPositions.forEach((lp) => {
    const led = new THREE.Mesh(ledGeo, new THREE.MeshBasicMaterial({ color: 0xeab308 }));
    led.position.set(lp.x, 0.35, lp.z);
    houseGroup.add(led);
    ledMeshes.push(led);

    const light = new THREE.PointLight(0xeab308, 0.35, 3);
    light.position.set(lp.x, 0.6, lp.z);
    houseGroup.add(light);
    ledLights.push(light);
  });

  // ── PIR (red cone, outside top wall center) ──
  pirMesh = new THREE.Mesh(
    new THREE.ConeGeometry(0.28, 0.5, 8),
    new THREE.MeshPhongMaterial({ color: 0xef4444, emissive: 0xef4444, emissiveIntensity: 0.3 })
  );
  pirMesh.position.set(0, 0.5, -(HD + 1));
  pirMesh.rotation.x = Math.PI;
  houseGroup.add(pirMesh);
  const pirLight = new THREE.PointLight(0xef4444, 0.25, 3);
  pirLight.position.set(0, 0.8, -(HD + 1));
  houseGroup.add(pirLight);

  // ── LDR (green sphere, outside left wall) ──
  ldrMesh = new THREE.Mesh(
    new THREE.SphereGeometry(0.24, 12, 12),
    new THREE.MeshPhongMaterial({ color: 0x22c55e, emissive: 0x22c55e, emissiveIntensity: 0.3 })
  );
  ldrMesh.position.set(-(HW + 1), 0.4, 0);
  houseGroup.add(ldrMesh);
  const ldrLight = new THREE.PointLight(0x22c55e, 0.25, 3);
  ldrLight.position.set(-(HW + 1), 0.6, 0);
  houseGroup.add(ldrLight);

  // ── Buzzer (purple octahedron, outside right wall) ──
  buzMesh = new THREE.Mesh(
    new THREE.OctahedronGeometry(0.26, 0),
    new THREE.MeshPhongMaterial({ color: 0x8b5cf6, emissive: 0x8b5cf6, emissiveIntensity: 0.3 })
  );
  buzMesh.position.set(HW + 1, 0.42, 0);
  houseGroup.add(buzMesh);
  const buzLight = new THREE.PointLight(0x8b5cf6, 0.25, 3);
  buzLight.position.set(HW + 1, 0.6, 0);
  houseGroup.add(buzLight);

  // ── Labels ──
  function makeLabel(text, x, z, color, size) {
    const c = document.createElement('canvas');
    const fontSize = size || 28;
    c.width = 256; c.height = 64;
    const ctx = c.getContext('2d');
    ctx.font = `bold ${fontSize}px Outfit, sans-serif`;
    ctx.fillStyle = color || '#334155';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(text, 128, 32);
    const tex = new THREE.CanvasTexture(c);
    const s = new THREE.Sprite(new THREE.SpriteMaterial({ map: tex, transparent: true, opacity: 0.85 }));
    s.position.set(x, 0.8, z);
    s.scale.set(2.4, 0.6, 1);
    houseGroup.add(s);
  }

  function makeSmallLabel(text, x, z, color) {
    const c = document.createElement('canvas');
    c.width = 128; c.height = 40;
    const ctx = c.getContext('2d');
    ctx.font = 'bold 18px Outfit, sans-serif';
    ctx.fillStyle = color || '#64748b';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(text, 64, 20);
    const tex = new THREE.CanvasTexture(c);
    const s = new THREE.Sprite(new THREE.SpriteMaterial({ map: tex, transparent: true, opacity: 0.7 }));
    s.position.set(x, 1.05, z);
    s.scale.set(1.2, 0.38, 1);
    houseGroup.add(s);
  }

  // Label center
  makeLabel('Smart Home', 0, 0, '#2563eb');

  // Label each LED (1-indexed for user)
  ledPositions.forEach((lp, i) => {
    makeSmallLabel(`LED ${i + 1}`, lp.x, lp.z, '#92400e');
  });

  // Sensor labels
  makeSmallLabel('PIR', 0, -(HD + 1), '#dc2626');
  makeSmallLabel('LDR', -(HW + 1), 0, '#16a34a');
  makeSmallLabel('Buzzer', HW + 1, 0, '#7c3aed');

  houseScene.add(houseGroup);
}

// ── Resize ──
function resizeHouseCanvas() {
  if (!houseCanvas || !houseRenderer) return;
  const p = houseCanvas.parentElement;
  if (!p) return;
  houseRenderer.setSize(p.clientWidth, p.clientHeight);
  houseCamera.aspect = p.clientWidth / p.clientHeight;
  houseCamera.updateProjectionMatrix();
}
resizeHouseCanvas();

// ── Mouse ──
let mouseX = 0, mouseY = 0, tMX = 0, tMY = 0;
document.addEventListener('mousemove', (e) => {
  tMX = (e.clientX / window.innerWidth - 0.5) * 2;
  tMY = (e.clientY / window.innerHeight - 0.5) * 2;
});

// ── Animate ──
let time = 0;

function animate() {
  requestAnimationFrame(animate);
  time += 0.001;
  mouseX += (tMX - mouseX) * 0.02;
  mouseY += (tMY - mouseY) * 0.02;

  if (currentSlide === 0 && houseRenderer) {
    houseGroup.rotation.y = mouseX * 0.12;
    houseGroup.rotation.x = mouseY * 0.04;

    // LED pulse
    const pulse = 0.7 + Math.sin(time * 600) * 0.3;
    ledLights.forEach(l => { l.intensity = 0.15 + Math.sin(time * 600) * 0.2; });

    if (pirMesh) pirMesh.rotation.y += 0.012;
    if (buzMesh) buzMesh.rotation.y += 0.008;
    if (ldrMesh) {
      const s = 1 + Math.sin(time * 400) * 0.12;
      ldrMesh.scale.set(s, s, s);
    }

    houseRenderer.render(houseScene, houseCamera);
  }
}
animate();

window.addEventListener('resize', resizeHouseCanvas);

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
  slideCounter.textContent = `${String(currentSlide + 1).padStart(2, '0')} / ${String(totalSlides).padStart(2, '0')}`;
  navDotsContainer.querySelectorAll('.nav-dot').forEach((d, i) => d.classList.toggle('active', i === currentSlide));
  prevBtn.style.opacity = currentSlide === 0 ? '0.3' : '1';
  prevBtn.style.pointerEvents = currentSlide === 0 ? 'none' : 'auto';
  nextBtn.style.opacity = currentSlide === totalSlides - 1 ? '0.3' : '1';
  nextBtn.style.pointerEvents = currentSlide === totalSlides - 1 ? 'none' : 'auto';
}

function goToSlide(index) {
  if (index === currentSlide || isTransitioning || index < 0 || index >= totalSlides) return;
  isTransitioning = true;
  const dir = index > currentSlide ? 1 : -1;
  const cur = slides[currentSlide], nxt = slides[index];

  cur.classList.remove('active');
  cur.classList.add(dir > 0 ? 'exit-left' : '');
  if (dir < 0) cur.style.transform = 'translateX(80px) rotateY(-5deg) scale(0.95)';

  nxt.style.transform = dir > 0
    ? 'translateX(80px) rotateY(-5deg) scale(0.95)'
    : 'translateX(-80px) rotateY(5deg) scale(0.95)';
  if (dir < 0) nxt.classList.remove('exit-left');
  void nxt.offsetWidth;
  nxt.classList.add('active');
  nxt.style.transform = '';

  currentSlide = index;
  updateUI();

  setTimeout(() => { cur.classList.remove('exit-left'); cur.style.transform = ''; isTransitioning = false; }, 800);
}

prevBtn.addEventListener('click', () => goToSlide(currentSlide - 1));
nextBtn.addEventListener('click', () => goToSlide(currentSlide + 1));

document.addEventListener('keydown', (e) => {
  if (e.key === 'ArrowRight' || e.key === 'ArrowDown' || e.key === ' ') { e.preventDefault(); goToSlide(currentSlide + 1); }
  else if (e.key === 'ArrowLeft' || e.key === 'ArrowUp') { e.preventDefault(); goToSlide(currentSlide - 1); }
});

let scrollCD = false;
document.addEventListener('wheel', (e) => {
  if (scrollCD) return; scrollCD = true;
  if (e.deltaY > 30) goToSlide(currentSlide + 1); else if (e.deltaY < -30) goToSlide(currentSlide - 1);
  setTimeout(() => { scrollCD = false; }, 1000);
}, { passive: true });

let tSX = 0;
document.addEventListener('touchstart', (e) => { tSX = e.changedTouches[0].screenX; }, { passive: true });
document.addEventListener('touchend', (e) => {
  const dx = e.changedTouches[0].screenX - tSX;
  if (Math.abs(dx) > 60) { dx < 0 ? goToSlide(currentSlide + 1) : goToSlide(currentSlide - 1); }
}, { passive: true });

updateUI();
