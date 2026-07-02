-- Shared palette, kept in sync with the @thm_* overrides in ~/.tmux.conf
-- and the background/foreground/palette values in ~/.config/ghostty/config.
-- Defined in HSL so new entries are picked by adjusting one clear lightness
-- step rather than guessing hex.

-- l is a 0-255 channel value (matches hex byte values); h is degrees, s is 0-1.
local function hsl_to_hex(h, s, l)
  l = l / 255

  local function hue2rgb(p, q, t)
    if t < 0 then
      t = t + 1
    end
    if t > 1 then
      t = t - 1
    end
    if t < 1 / 6 then
      return p + (q - p) * 6 * t
    end
    if t < 1 / 2 then
      return q
    end
    if t < 2 / 3 then
      return p + (q - p) * (2 / 3 - t) * 6
    end
    return p
  end

  local r, g, b
  if s == 0 then
    r, g, b = l, l, l
  else
    local q = l < 0.5 and l * (1 + s) or l + s - l * s
    local p = 2 * l - q
    r = hue2rgb(p, q, h / 360 + 1 / 3)
    g = hue2rgb(p, q, h / 360)
    b = hue2rgb(p, q, h / 360 - 1 / 3)
  end

  return string.format('#%02x%02x%02x', math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

-- hsl_to_hex(hue, saturation, lightness) -- all neutral grays below (s=0),
-- differing only by lightness, so the ramp reads top-to-bottom light to dark.
-- Lightness values are round multiples of 5 for readability.
return {
  fg = hsl_to_hex(0, 0, 215),
  subtext1 = hsl_to_hex(0, 0, 195),
  subtext0 = hsl_to_hex(0, 0, 175),
  overlay2 = hsl_to_hex(0, 0, 110),
  overlay1 = hsl_to_hex(0, 0, 95),
  overlay0 = hsl_to_hex(0, 0, 80),
  surface2 = hsl_to_hex(0, 0, 65),
  surface1 = hsl_to_hex(0, 0, 55),
  surface0 = hsl_to_hex(0, 0, 40),
  bg = hsl_to_hex(0, 0, 25),
  mantle = hsl_to_hex(0, 0, 20),
  crust = hsl_to_hex(0, 0, 10),
}
