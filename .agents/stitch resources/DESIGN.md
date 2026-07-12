---
name: Lumina Smart Systems
colors:
  surface: '#f5fafd'
  surface-dim: '#d5dbde'
  surface-bright: '#f5fafd'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#eff4f7'
  surface-container: '#e9eff1'
  surface-container-high: '#e3e9ec'
  surface-container-highest: '#dee3e6'
  on-surface: '#171c1f'
  on-surface-variant: '#3d494d'
  inverse-surface: '#2b3134'
  inverse-on-surface: '#ecf2f4'
  outline: '#6d797e'
  outline-variant: '#bcc9ce'
  surface-tint: '#00677d'
  primary: '#00677d'
  on-primary: '#ffffff'
  primary-container: '#00b4d8'
  on-primary-container: '#00414f'
  inverse-primary: '#4cd6fb'
  secondary: '#006d37'
  on-secondary: '#ffffff'
  secondary-container: '#6bfe9c'
  on-secondary-container: '#00743a'
  tertiary: '#006590'
  on-tertiary: '#ffffff'
  tertiary-container: '#55aee4'
  on-tertiary-container: '#003f5c'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#b3ebff'
  primary-fixed-dim: '#4cd6fb'
  on-primary-fixed: '#001f27'
  on-primary-fixed-variant: '#004e5f'
  secondary-fixed: '#6bfe9c'
  secondary-fixed-dim: '#4ae183'
  on-secondary-fixed: '#00210c'
  on-secondary-fixed-variant: '#005228'
  tertiary-fixed: '#c8e6ff'
  tertiary-fixed-dim: '#87ceff'
  on-tertiary-fixed: '#001e2e'
  on-tertiary-fixed-variant: '#004c6d'
  background: '#f5fafd'
  on-background: '#171c1f'
  surface-variant: '#dee3e6'
typography:
  display-lg:
    fontFamily: Manrope
    fontSize: 48px
    fontWeight: '700'
    lineHeight: 56px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Manrope
    fontSize: 32px
    fontWeight: '600'
    lineHeight: 40px
    letterSpacing: -0.01em
  headline-lg-mobile:
    fontFamily: Manrope
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  title-md:
    fontFamily: Manrope
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  body-lg:
    fontFamily: Manrope
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-md:
    fontFamily: Manrope
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  label-sm:
    fontFamily: Hanken Grotesk
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.05em
rounded:
  sm: 0.5rem
  DEFAULT: 1rem
  md: 1.5rem
  lg: 2rem
  xl: 3rem
  full: 9999px
spacing:
  base: 8px
  container-padding-mobile: 20px
  container-padding-desktop: 40px
  gutter: 16px
  stack-gap: 24px
---

## Brand & Style
The design system embodies a premium, modern smart-home experience that feels both technologically advanced and domestic. It targets homeowners who value seamless automation and aesthetic harmony. The visual direction is a fusion of **Glassmorphism** and **Modern Corporate**, utilizing translucent layers and vibrant blurs to create a sense of depth and lightness. 

The emotional response should be one of "effortless control"—calm, responsive, and optimistic. The brand identity is purely typographic, relying on precise letterspacing and weight contrast rather than icons or logos to convey authority.

## Colors
This design system utilizes a high-vibrancy palette set against a soothing, off-white/lavender gray background. 

- **Primary (Modern Teal):** Used for active states, primary toggles, and critical action buttons.
- **Secondary (Bright Mint):** Reserved for "Active" or "Eco-friendly" status indicators, such as energy-saving modes.
- **Tertiary (Soft Electric Blue):** Used for ambient lighting controls and secondary interactive elements.
- **Background:** A soft #F4F6FA wash that reduces eye strain compared to pure white, providing a canvas for glassmorphic cards.
- **Surface:** Pure white (#FFFFFF) with varying levels of opacity (70-90%) for the glassmorphic effect.

## Typography
The typography strategy uses **Manrope** for its balanced, modern proportions which feel both technical and friendly. For headlines, tight tracking and medium-to-bold weights are used to establish a strong hierarchy. **Hanken Grotesk** is introduced for small labels and data points, providing a sharp, contemporary "developer" aesthetic to technical readouts like temperature or wattage.

## Elevation & Depth
Depth is the primary communicator of interactivity. This design system avoids harsh shadows in favor of **Ambient Glassmorphism**:
- **Base Layer:** The lavender-gray background (#F4F6FA).
- **Surface Layer:** White cards at 80% opacity with a `20px` backdrop blur.
- **Elevation 1 (Floating):** Used for main cards. A very soft, tinted shadow: `0px 10px 30px rgba(0, 180, 216, 0.08)`.
- **Elevation 2 (Active):** When a smart device is "On," the card glow increases using a subtle outer glow of the device's accent color (Teal or Mint) rather than a neutral shadow.

## Shapes
The shape language is defined by extreme "squircle" roundedness. 
- **Large Cards:** Use `32px` corner radius to evoke a soft, consumer-electronics feel.
- **Buttons and Inputs:** Use `rounded-full` (pill-shaped) to maximize the friendly, approachable nature of the interface.
- **Interactive Toggles:** All switch stems and sliders should use rounded caps.

## Components
- **Buttons:** Primary buttons are pill-shaped with a vibrant Modern Teal gradient. Text is white, semi-bold. Secondary buttons use a "ghost" style with a 1.5px Teal border.
- **Smart Cards:** These are the heart of the UI. They must feature a glassmorphic background. When the device is "Off," the icon and text are muted gray. When "On," the card background remains glass, but the icon adopts the Primary or Secondary accent color and a subtle glow.
- **Glass Sliders (Dimmers/Thermostats):** Use a thick track with a high-contrast white handle. The filled portion of the track should use the Soft Electric Blue gradient.
- **Chips/Status Tags:** Small, semi-transparent pills used for sensor data (e.g., "72°F", "No Motion").
- **Segmented Control:** A recessed track with a floating glass "indicator" that slides between options.