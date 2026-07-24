import { motion } from 'framer-motion';

const STEPS = [
  { id: 1, label: 'Connect' },
  { id: 2, label: 'Pick jobs' },
  { id: 3, label: 'Package' },
];

export default function Stepper({ step }) {
  return (
    <div className="stepper" aria-label="Wizard progress">
      {STEPS.map((s, i) => (
        <div key={s.id} style={{ display: 'contents' }}>
          {i > 0 && <span className="step-sep">—</span>}
          <motion.div
            className={`step-pill ${step === s.id ? 'active' : ''} ${step > s.id ? 'done' : ''}`}
            layout
            transition={{ type: 'spring', stiffness: 380, damping: 28 }}
          >
            <span className="step-num">{s.id}</span>
            {s.label}
          </motion.div>
        </div>
      ))}
    </div>
  );
}
