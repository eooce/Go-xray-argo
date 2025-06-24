<template>
  <div id="app">
    <router-view />
  </div>
</template>

<script>
export default { name: 'App' }
</script>

<style lang="scss">
html, body {
  height: 100%;
  margin: 0;
  padding: 0;
  overflow: hidden; /* Prevent scrollbars on the body */
}

#app {
  height: 100%;
  display: flex;
  flex-direction: column;

  > div {
    flex-grow: 1;
    display: flex;
    flex-direction: column;
  }
}
</style>
