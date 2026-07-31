import { defineConfig } from 'vite';

// GitHub Pages sirve este proyecto en /enterrario-aloesativo/, no en la raíz
// del dominio (aloesativo.github.io/). `base` le dice a Vite que arme las
// rutas de los assets compilados relativas a esa subruta.
export default defineConfig({
  base: '/enterrario-aloesativo/',
});
