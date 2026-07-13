/* ============================================
   Smart Home IoT — 3D Presentation Engine
   Three.js Particle Background + Slide Logic
   ============================================ */

// ──── Three.js 3D Scene ────
const canvas = document.getElementById('bg-canvas');
const scene = new THREE.Scene();
const camera = new THREE.PerspectiveCamera(75, window.innerWidth / window.innerHeight, 0.1, 1000);
const renderer = new THREE.WebGLRenderer({ canvas, alpha: true, antialias: true });
renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
renderer.setSize(window.innerWidth, window.innerHeight);

camera.position.z = 30;

// ── Color palette per slide ──
const slideColors = [
  { primary: 0x00e5ff, secondary: 0xa855f7 },  // Slide 1: Cyan + Purple
  { primary: 0x3b82f6, secondary: 0x14b8a6 },  // Slide 2: Blue + Teal
  { primary: 0xf59e0b, secondary: 0xec4899 },  // Slide 3: Orange + Pink
  { primary: 0x54c5f8, secondary: 0x4ade80 },  // Slide 4: Flutter Blue + Green
];

// ── Particle System ──
const PARTICLE_COUNT = 1200;
const particlesGeometry = new THREE.BufferGeometry();
const posArray = new Float32Array(PARTICLE_COUNT * 3);
const velocityArray = new Float32Array(PARTICLE_COUNT * 3);

for (let i = 0; i < PARTICLE_COUNT * 3; i += 3) {
  posArray[i]     = (Math.random() - 0.5) * 80;
  posArray[i + 1] = (Math.random() - 0.5) * 80;
  posArray[i + 2] = (Math.random() - 0.5) * 80;
  velocityArray[i]     = (Math.random() - 0.5) * 0.008;
  velocityArray[i + 1] = (Math.random() - 0.5) * 0.008;
  velocityArray[i + 2] = (Math.random() - 0.5) * 0.008;
}

particlesGeometry.setAttribute('position', new THREE.BufferAttribute(posArray, 3));

const particlesMaterial = new THREE.PointsMaterial({
  size: 0.08,
  color: 0x00e5ff,
  transparent: true,
  opacity: 0.6,
  blending: THREE.AdditiveBlending,
  sizeAttenuation: true,
});

const particlesMesh = new THREE.Points(particlesGeometry, particlesMaterial);
scene.add(particlesMesh);

// ── Floating Geometric Objects ──
const geometries = [
  new THREE.IcosahedronGeometry(1.2, 0),
  new THREE.TorusGeometry(1, 0.35, 16, 32),
  new THREE.OctahedronGeometry(1, 0),
  new THREE.TorusKnotGeometry(0.8, 0.25, 64, 8, 2, 3),
];

const floatingObjects = [];

for (let i = 0; i < 6; i++) {
  const geo = geometries[i % geometries.length];
  const mat = new THREE.MeshBasicMaterial({
    color: i % 2 === 0 ? 0x00e5ff : 0xa855f7,
    wireframe: true,
    transparent: true,
    opacity: 0.12,
  });
  const mesh = new THREE.Mesh(geo, mat);

  mesh.position.set(
    (Math.random() - 0.5) * 50,
    (Math.random() - 0.5) * 30,
    (Math.random() - 0.5) * 20 - 10
  );

  mesh.userData = {
    rotSpeed: { x: Math.random() * 0.003 + 0.001, y: Math.random() * 0.003 + 0.001 },
    floatSpeed: Math.random() * 0.0005 + 0.0003,
    floatAmp: Math.random() * 3 + 1,
    baseY: mesh.position.y,
    materialRef: mat,
  };

  scene.add(mesh);
  floatingObjects.push(mesh);
}

// ── Connecting Lines (constellation effect) ──
const linesMaterial = new THREE.LineBasicMaterial({
  color: 0x00e5ff,
  transparent: true,
  opacity: 0.04,
  blending: THREE.AdditiveBlending,
});

const linesGeometry = new THREE.BufferGeometry();
const linePositions = new Float32Array(100 * 6);
linesGeometry.setAttribute('position', new THREE.BufferAttribute(linePositions, 3));
const constellationLines = new THREE.LineSegments(linesGeometry, linesMaterial);
scene.add(constellationLines);

// ── Mouse interaction ──
let mouseX = 0, mouseY = 0;
let targetMouseX = 0, targetMouseY = 0;

document.addEventListener('mousemove', (e) => {
  targetMouseX = (e.clientX / window.innerWidth - 0.5) * 2;
  targetMouseY = (e.clientY / window.innerHeight - 0.5) * 2;
});

// ── Animate Scene ──
let time = 0;
let currentColorTarget = slideColors[0];

function updateConstellationLines() {
  const positions = particlesGeometry.attributes.position.array;
  let lineIdx = 0;
  const maxLines = 50;
  const threshold = 12;

  for (let i = 0; i < PARTICLE_COUNT * 3 && lineIdx < maxLines; i += 30) {
    for (let j = i + 3; j < Math.min(i + 90, PARTICLE_COUNT * 3) && lineIdx < maxLines; j += 30) {
      const dx = positions[i] - positions[j];
      const dy = positions[i + 1] - positions[j + 1];
      const dz = positions[i + 2] - positions[j + 2];
      const dist = Math.sqrt(dx * dx + dy * dy + dz * dz);

      if (dist < threshold) {
        const lp = constellationLines.geometry.attributes.position.array;
        const li = lineIdx * 6;
        lp[li]     = positions[i];
        lp[li + 1] = positions[i + 1];
        lp[li + 2] = positions[i + 2];
        lp[li + 3] = positions[j];
        lp[li + 4] = positions[j + 1];
        lp[li + 5] = positions[j + 2];
        lineIdx++;
      }
    }
  }

  for (let k = lineIdx * 6; k < linePositions.length; k++) {
    constellationLines.geometry.attributes.position.array[k] = 0;
  }
  constellationLines.geometry.attributes.position.needsUpdate = true;
}

function animate() {
  requestAnimationFrame(animate);
  time += 0.001;

  // Smooth mouse follow
  mouseX += (targetMouseX - mouseX) * 0.02;
  mouseY += (targetMouseY - mouseY) * 0.02;

  // Rotate particle field
  particlesMesh.rotation.y = time * 0.3 + mouseX * 0.15;
  particlesMesh.rotation.x = mouseY * 0.08;

  // Animate particles
  const positions = particlesGeometry.attributes.position.array;
  for (let i = 0; i < PARTICLE_COUNT * 3; i += 3) {
    positions[i]     += velocityArray[i];
    positions[i + 1] += velocityArray[i + 1];
    positions[i + 2] += velocityArray[i + 2];

    // Wrap around boundaries
    if (Math.abs(positions[i]) > 40) velocityArray[i] *= -1;
    if (Math.abs(positions[i + 1]) > 40) velocityArray[i + 1] *= -1;
    if (Math.abs(positions[i + 2]) > 40) velocityArray[i + 2] *= -1;
  }
  particlesGeometry.attributes.position.needsUpdate = true;

  // Floating objects animation
  floatingObjects.forEach((obj) => {
    const ud = obj.userData;
    obj.rotation.x += ud.rotSpeed.x;
    obj.rotation.y += ud.rotSpeed.y;
    obj.position.y = ud.baseY + Math.sin(time * 400 * ud.floatSpeed) * ud.floatAmp;
  });

  // Color transition
  const currentPColor = new THREE.Color(particlesMaterial.color);
  const targetPColor = new THREE.Color(currentColorTarget.primary);
  currentPColor.lerp(targetPColor, 0.02);
  particlesMaterial.color = currentPColor;

  linesMaterial.color.copy(currentPColor);

  floatingObjects.forEach((obj, i) => {
    const tgt = new THREE.Color(i % 2 === 0 ? currentColorTarget.primary : currentColorTarget.secondary);
    obj.userData.materialRef.color.lerp(tgt, 0.02);
  });

  // Update constellation
  if (Math.floor(time * 1000) % 5 === 0) {
    updateConstellationLines();
  }

  renderer.render(scene, camera);
}

animate();

// ── Resize handler ──
window.addEventListener('resize', () => {
  camera.aspect = window.innerWidth / window.innerHeight;
  camera.updateProjectionMatrix();
  renderer.setSize(window.innerWidth, window.innerHeight);
});


// ──── Slide Navigation Engine ────
const slides = document.querySelectorAll('.slide');
const totalSlides = slides.length;
let currentSlide = 0;
let isTransitioning = false;

const progressFill = document.getElementById('progressFill');
const slideCounter = document.getElementById('slideCounter');
const navDotsContainer = document.getElementById('navDots');
const prevBtn = document.getElementById('prevBtn');
const nextBtn = document.getElementById('nextBtn');

// Build nav dots
for (let i = 0; i < totalSlides; i++) {
  const dot = document.createElement('div');
  dot.className = 'nav-dot' + (i === 0 ? ' active' : '');
  dot.addEventListener('click', () => goToSlide(i));
  navDotsContainer.appendChild(dot);
}

function updateUI() {
  // Progress bar
  progressFill.style.width = `${((currentSlide + 1) / totalSlides) * 100}%`;

  // Slide counter
  const num = String(currentSlide + 1).padStart(2, '0');
  const total = String(totalSlides).padStart(2, '0');
  slideCounter.textContent = `${num} / ${total}`;

  // Nav dots
  const dots = navDotsContainer.querySelectorAll('.nav-dot');
  dots.forEach((d, i) => d.classList.toggle('active', i === currentSlide));

  // Arrow visibility
  prevBtn.style.opacity = currentSlide === 0 ? '0.3' : '1';
  prevBtn.style.pointerEvents = currentSlide === 0 ? 'none' : 'auto';

  nextBtn.style.opacity = currentSlide === totalSlides - 1 ? '0.3' : '1';
  nextBtn.style.pointerEvents = currentSlide === totalSlides - 1 ? 'none' : 'auto';

  // Update 3D scene colors
  currentColorTarget = slideColors[currentSlide] || slideColors[0];
}

function goToSlide(index) {
  if (index === currentSlide || isTransitioning || index < 0 || index >= totalSlides) return;
  isTransitioning = true;

  const direction = index > currentSlide ? 1 : -1;
  const currentEl = slides[currentSlide];
  const nextEl = slides[index];

  // Exit current slide
  currentEl.classList.remove('active');
  currentEl.classList.add(direction > 0 ? 'exit-left' : '');
  if (direction < 0) {
    currentEl.style.transform = 'translateX(80px) rotateY(-5deg) scale(0.95)';
  }

  // Prepare next slide entry direction
  if (direction > 0) {
    nextEl.style.transform = 'translateX(80px) rotateY(-5deg) scale(0.95)';
  } else {
    nextEl.style.transform = 'translateX(-80px) rotateY(5deg) scale(0.95)';
    nextEl.classList.remove('exit-left');
  }

  // Force reflow
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

// ── Event Listeners ──
prevBtn.addEventListener('click', prevSlide);
nextBtn.addEventListener('click', nextSlide);

// Keyboard navigation
document.addEventListener('keydown', (e) => {
  if (e.key === 'ArrowRight' || e.key === 'ArrowDown' || e.key === ' ') {
    e.preventDefault();
    nextSlide();
  } else if (e.key === 'ArrowLeft' || e.key === 'ArrowUp') {
    e.preventDefault();
    prevSlide();
  }
});

// Scroll / wheel navigation
let scrollCooldown = false;
document.addEventListener('wheel', (e) => {
  if (scrollCooldown) return;
  scrollCooldown = true;

  if (e.deltaY > 30) nextSlide();
  else if (e.deltaY < -30) prevSlide();

  setTimeout(() => { scrollCooldown = false; }, 1000);
}, { passive: true });

// Touch swipe navigation
let touchStartX = 0;
let touchStartY = 0;

document.addEventListener('touchstart', (e) => {
  touchStartX = e.changedTouches[0].screenX;
  touchStartY = e.changedTouches[0].screenY;
}, { passive: true });

document.addEventListener('touchend', (e) => {
  const dx = e.changedTouches[0].screenX - touchStartX;
  const dy = e.changedTouches[0].screenY - touchStartY;

  if (Math.abs(dx) > Math.abs(dy) && Math.abs(dx) > 60) {
    if (dx < 0) nextSlide();
    else prevSlide();
  }
}, { passive: true });

// Initialize
updateUI();
