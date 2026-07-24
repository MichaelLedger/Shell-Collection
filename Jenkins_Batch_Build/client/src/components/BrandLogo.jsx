/** Batch / pipeline mark — stacked layers with a play cue */
export default function BrandLogo({ size = 28 }) {
  return (
    <svg
      className="brand-mark"
      width={size}
      height={size}
      viewBox="0 0 32 32"
      aria-hidden="true"
    >
      <rect width="32" height="32" rx="6" fill="rgba(255,255,255,0.18)" />
      <rect x="7" y="7" width="18" height="4" rx="1.5" fill="#fff" opacity="0.45" />
      <rect x="7" y="13" width="18" height="4" rx="1.5" fill="#fff" opacity="0.7" />
      <rect x="7" y="19" width="11" height="4" rx="1.5" fill="#fff" />
      <path d="M21.5 18.2v7.6L28 22z" fill="#FFE380" />
    </svg>
  );
}
