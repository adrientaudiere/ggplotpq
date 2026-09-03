################################################################################
# OKLCH colour engine for pqverse palettes
#
# OKLCH is the polar form of the OKLab perceptual colour space (Ottosson 2020).
# Its lightness axis is perceptually uniform, which makes it the right space to
# build qualitative palettes (constant L and C, varying H) and nested gradients
# (constant H, varying L) without the lightness bumps that plague HSV and HCL.
#
# `farver` speaks "oklch" natively, but silently clamps out-of-gamut colours to
# the sRGB cube. The clamping is not a small nudge: a requested (L = .45,
# C = .30, H = 58) orange comes back as a pure red at H = 29, a 29 degree hue
# shift. Detecting this requires an unclamped conversion, which farver does not
# expose, hence the explicit OKLab -> linear sRGB matrix below.
################################################################################

#' OKLab to linear sRGB (unclamped)
#'
#' Ottosson's inverse matrix. Unlike [farver::convert_colour()], the result is
#' *not* clamped to the sRGB cube: channels outside `[0, 1]` are the signal that
#' the colour is out of gamut.
#'
#' @param L,a,b Numeric vectors of OKLab coordinates.
#'
#' @return A numeric matrix with columns `r`, `g`, `b` in linear sRGB, possibly
#'   outside `[0, 1]`.
#' @noRd
.pq_oklab_to_linear_srgb <- function(L, a, b) {
  l_ <- L + 0.3963377774 * a + 0.2158037573 * b
  m_ <- L - 0.1055613458 * a - 0.0638541728 * b
  s_ <- L - 0.0894841775 * a - 1.2914855480 * b

  l <- l_^3
  m <- m_^3
  s <- s_^3

  cbind(
    r = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
    g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
    b = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
  )
}

#' OKLCH to sRGB (unclamped, 0-1 scale)
#'
#' @param m A numeric matrix with columns `l` (0-1), `c` (0-0.4ish) and `h`
#'   (degrees).
#'
#' @return A numeric matrix with columns `r`, `g`, `b` on a 0-1 scale, possibly
#'   outside `[0, 1]` when the colour is out of the sRGB gamut.
#' @noRd
.pq_oklch_to_srgb <- function(m) {
  hr <- m[, "h"] * pi / 180
  lin <- .pq_oklab_to_linear_srgb(
    m[, "l"],
    m[, "c"] * cos(hr),
    m[, "c"] * sin(hr)
  )
  # Linear sRGB -> gamma-encoded sRGB. The transfer function is only defined
  # for non-negative inputs, so negative channels (out of gamut) keep their
  # sign through an odd extension; only their sign matters downstream.
  sgn <- sign(lin)
  a <- abs(lin)
  enc <- ifelse(a <= 0.0031308, 12.92 * a, 1.055 * a^(1 / 2.4) - 0.055)
  sgn * enc
}

#' Is an OKLCH colour inside the sRGB gamut?
#'
#' @param m A numeric matrix with columns `l`, `c`, `h`.
#' @param eps (numeric, default `1 / 255`) Tolerance on each sRGB channel. One
#'   8-bit quantisation step: a colour within that distance of the cube is
#'   representable as a hex value, and the round trip
#'   `oklch -> hex -> oklch -> sRGB` lands up to ~0.3 steps outside the cube on
#'   pure floating-point noise. A tighter tolerance rejects colours that are in
#'   fact perfectly displayable.
#'
#' @return A logical vector, one element per row of `m`.
#' @noRd
.pq_in_gamut <- function(m, eps = 1 / 255) {
  rgb <- .pq_oklch_to_srgb(m)
  lo <- rgb >= -eps
  hi <- rgb <= 1 + eps
  as.vector(apply(lo & hi, 1, all))
}

#' Map OKLCH colours into the sRGB gamut by reducing chroma
#'
#' Out-of-gamut colours keep their lightness and hue, and lose only as much
#' chroma as needed. This is the CSS Color 4 gamut mapping strategy, and it is
#' what makes a nested gradient safe: naively clamping in sRGB collapses
#' distinct shades onto the same hex value and shifts hues by tens of degrees.
#'
#' @param m A numeric matrix with columns `l`, `c`, `h`.
#' @param max_iter (integer, default `20`) Bisection steps. 20 steps resolve
#'   chroma to about 1e-6, far below perceptual threshold.
#'
#' @return A numeric matrix with the same shape as `m`, every row in gamut.
#' @noRd
.pq_gamut_map_oklch <- function(m, max_iter = 20) {
  m <- .pq_as_oklch_matrix(m)
  ok <- .pq_in_gamut(m)
  if (all(ok)) {
    return(m)
  }

  idx <- which(!ok)
  lo <- rep(0, length(idx))
  hi <- m[idx, "c"]

  for (i in seq_len(max_iter)) {
    mid <- (lo + hi) / 2
    probe <- m[idx, , drop = FALSE]
    probe[, "c"] <- mid
    inside <- .pq_in_gamut(probe)
    lo[inside] <- mid[inside]
    hi[!inside] <- mid[!inside]
  }

  # `lo` is the largest chroma known to be inside the gamut.
  m[idx, "c"] <- lo
  m
}

#' Coerce to a well-formed OKLCH matrix
#'
#' @param m A numeric matrix or vector of OKLCH coordinates.
#'
#' @return A numeric matrix with columns `l`, `c`, `h`.
#' @noRd
.pq_as_oklch_matrix <- function(m) {
  if (is.null(dim(m))) {
    m <- matrix(m, nrow = 1)
  }
  if (ncol(m) != 3) {
    cli::cli_abort("An OKLCH matrix must have exactly 3 columns (l, c, h).")
  }
  colnames(m) <- c("l", "c", "h")
  m
}

#' Convert OKLCH coordinates to hex colours, gamut-mapped
#'
#' @param m A numeric matrix with columns `l`, `c`, `h`.
#'
#' @return A character vector of hex colours.
#' @noRd
.pq_oklch_hex <- function(m) {
  m <- .pq_gamut_map_oklch(m)
  farver::encode_colour(m, from = "oklch")
}

#' Convert hex colours to OKLCH coordinates
#'
#' @param x A character vector of colours accepted by [farver::decode_colour()].
#'
#' @return A numeric matrix with columns `l`, `c`, `h`.
#' @noRd
.pq_hex_oklch <- function(x) {
  .pq_as_oklch_matrix(farver::decode_colour(x, to = "oklch"))
}

#' Generate a qualitative palette in OKLCH
#'
#' Colours share a lightness and a chroma, so no single category is visually
#' heavier than the others - the property that HSV and HCL fail to deliver.
#'
#' Two regimes:
#'
#' - `n <= 8`: hues are spread evenly over `h_span`. With few categories this is
#'   both the most distinct and the most predictable layout.
#' - `n > 8`: even spacing puts neighbouring hues under 10 degrees apart, which
#'   no viewer can separate. Hue then advances by the golden angle (137.5) and
#'   lightness and chroma cycle over small offsets, so that consecutive
#'   categories - the ones that end up adjacent in a legend or a stacked bar -
#'   differ on three axes at once rather than on hue alone.
#'
#' Beyond 25 colours the palette degrades: the minimum pairwise CIE Lab
#' distance measured on this generator is 33.5 at n = 6, 17.2 at n = 12 and
#' only 5.2 at n = 40. Consecutive entries stay well separated, so legends and
#' stacked bars remain readable, but two arbitrary categories may look alike.
#' Hence the warning past 25 and the hard stop past 40.
#'
#' @param n (integer, required) Number of colours. At most 40.
#' @param l (numeric, default `0.62`) Base OKLCH lightness, 0-1.
#' @param c (numeric, default `0.17`) Base OKLCH chroma. Blues and violets
#'   cannot hold this much chroma in sRGB and are reduced by the gamut mapper,
#'   which costs a little saturation but never shifts their hue.
#' @param h_start (numeric, default `25`) Hue of the first colour, in degrees.
#' @param h_span (numeric, default `360`) Hue range to cover, in degrees.
#' @param vary (character, default `"auto"`) One of `"auto"`, `"hue"` or
#'   `"all"`. Forces one of the two regimes described above.
#'
#' @return A character vector of `n` hex colours.
#' @noRd
.pq_pal_oklch <- function(
  n,
  l = 0.62,
  c = 0.17,
  h_start = 25,
  h_span = 360,
  vary = "auto"
) {
  if (!is.numeric(n) || length(n) != 1 || is.na(n) || n < 1) {
    cli::cli_abort("{.arg n} must be a single positive number.")
  }
  n <- as.integer(n)

  if (n > 40) {
    cli::cli_abort(c(
      "x" = "{.arg n} is {n}; no qualitative palette holds more than 40 distinguishable colours.",
      "i" = "Group the rare categories into an {.val other} level, or map them to a continuous scale."
    ))
  }
  if (n > 25) {
    cli::cli_warn(c(
      "!" = "{n} colours requested: some pairs will be hard to tell apart.",
      "i" = "Consider grouping the rare categories into an {.val other} level."
    ))
  }
  vary <- rlang::arg_match0(vary, c("auto", "hue", "all"))
  if (identical(vary, "auto")) {
    vary <- if (n <= 8) "hue" else "all"
  }

  i <- seq_len(n) - 1L

  if (identical(vary, "hue")) {
    h <- h_start + i * (h_span / n)
    ll <- rep(l, n)
    cc <- rep(c, n)
  } else {
    golden <- 137.50776405003785
    h <- h_start + i * golden
    # Three lightness levels and two chroma levels, cycled on periods that are
    # coprime with each other so the (L, C) pattern does not repeat until the
    # 6th colour.
    l_offset <- c(0, 0.12, -0.12)[(i %% 3L) + 1L]
    c_scale <- c(1, 0.72)[(i %% 2L) + 1L]
    ll <- l + l_offset
    cc <- c * c_scale
  }

  .pq_oklch_hex(cbind(l = ll, c = cc, h = h %% 360))
}

#' Generate a lightness gradient from a base colour in OKLCH
#'
#' Used both for nested palettes (one gradient per parent taxon) and for
#' sequential sample-variable palettes.
#'
#' `positions` and `n_total` are what make a nested palette stable across
#' subsets. Passing the rank of each level within the *reference* set, rather
#' than its index in whatever subset is being plotted, keeps a given level on
#' the same rung of the ramp no matter how many of its siblings are present.
#' Recomputing the ramp from the local count - what `ggnested` does - makes
#' every sibling shift colour as soon as one is filtered out.
#'
#' @param base (character or numeric matrix, required) A single colour, as hex
#'   or as a one-row OKLCH matrix. Its hue and chroma are kept.
#' @param positions (integer, required) 1-based ranks of the requested levels
#'   within the reference set.
#' @param n_total (integer, default `max(positions)`) Size of the reference set.
#' @param l_range (numeric, default `c(0.35, 0.82)`) Lightness bounds. Rank 1
#'   gets `l_range[1]`, so the first (typically most abundant) level is the
#'   darkest and most prominent.
#'
#' @return A character vector of hex colours, one per element of `positions`.
#' @noRd
.pq_gradient_oklch <- function(
  base,
  positions,
  n_total = max(positions),
  l_range = c(0.35, 0.82)
) {
  if (is.character(base)) {
    base <- .pq_hex_oklch(base)
  }
  base <- .pq_as_oklch_matrix(base)
  if (nrow(base) != 1) {
    cli::cli_abort("{.arg base} must be a single colour.")
  }
  if (!is.numeric(positions) || length(positions) < 1 || anyNA(positions)) {
    cli::cli_abort("{.arg positions} must be a non-empty numeric vector.")
  }
  if (n_total < max(positions)) {
    cli::cli_abort(
      "{.arg n_total} ({n_total}) must be at least max({.arg positions}) ({max(positions)})."
    )
  }

  if (n_total == 1) {
    t <- 0.5
  } else {
    t <- (positions - 1) / (n_total - 1)
  }

  ll <- l_range[1] + t * (l_range[2] - l_range[1])

  # Chroma is held constant; the gamut mapper reduces it where a very light or
  # very dark colour cannot hold it. Damping it here as well would flatten the
  # ramp for no perceptual gain.
  .pq_oklch_hex(cbind(
    l = ll,
    c = rep(base[1, "c"], length(t)),
    h = rep(base[1, "h"], length(t))
  ))
}
