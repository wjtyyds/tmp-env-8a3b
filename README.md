# css-layout-tests

Some basic tests for CSS positioning and flexbox. Nothing special here, just personal reference.

## Center a div

The easiest way to center a child element perfectly in the middle of the screen using Flexbox:

```css
.parent-container {
  display: flex;
  justify-content: center;
  align-items: center;
  height: 100vh;
  background-color: #fafafa;
}

.child-element {
  width: 200px;
  height: 200px;
  background-color: #333;
  color: white;
  text-align: center;
  line-height: 200px;
  border-radius: 8px;
  box-shadow: 0 4px 8px rgba(0,0,0,0.1);
}
```

## HTML Structure

```html
<div class="parent-container">
  <div class="child-element">
    Centered Text
  </div>
</div>
```

## TODO List
- [x] Flexbox method
- [ ] CSS Grid method
- [ ] Absolute positioning with transform
- [ ] Margin auto trick