import React from 'react';
import { motion } from 'framer-motion';

export interface FlyingDiscPayload {
  id: number;
  coverUrl: string;
  fromRect: { left: number; top: number; width: number; height: number };
  toRect: { left: number; top: number; width: number; height: number };
  reverse?: boolean;
}

interface FlyingDiscTransitionProps {
  payload: FlyingDiscPayload | null;
  onComplete: () => void;
}

/**
 * Shared Element Physics Bridge:
 * Flies a circular vinyl disc seamlessly between Explore/MiniPlayer and the Turntable Platter
 * using spring physics and subtle motion scale/sheen.
 */
export const FlyingDiscTransition: React.FC<FlyingDiscTransitionProps> = ({
  payload,
  onComplete,
}) => {
  if (!payload) return null;

  const { fromRect, toRect, coverUrl } = payload;

  return (
    <motion.div
      key={payload.id}
      initial={{
        left: fromRect.left,
        top: fromRect.top,
        width: fromRect.width,
        height: fromRect.height,
        opacity: 1,
        scale: 1,
      }}
      animate={{
        left: toRect.left,
        top: toRect.top,
        width: toRect.width,
        height: toRect.height,
        opacity: [1, 1, 0],
        scale: [1, 1.04, 1],
      }}
      transition={{
        duration: 0.52,
        ease: [0.22, 1, 0.36, 1],
        opacity: { times: [0, 0.78, 1], duration: 0.52 },
      }}
      onAnimationComplete={onComplete}
      style={{
        position: 'fixed',
        borderRadius: '50%',
        overflow: 'hidden',
        zIndex: 999,
        pointerEvents: 'none',
        background: '#090B0E',
        boxShadow: '0 22px 46px rgba(10,14,22,0.42)',
      }}
    >
      {/* Outer glossy vinyl ring morphing into platter disc */}
      <div
        style={{
          position: 'absolute',
          inset: 0,
          borderRadius: '50%',
          background:
            'radial-gradient(circle, rgba(255,255,255,0) 34%, rgba(16,18,24,0.92) 35%, rgba(8,9,12,0.98) 100%)',
        }}
      />
      <img
        src={coverUrl}
        alt=""
        style={{
          position: 'absolute',
          left: '50%',
          top: '50%',
          width: payload.reverse ? '36%' : '100%',
          height: payload.reverse ? '36%' : '100%',
          transform: 'translate(-50%, -50%)',
          borderRadius: '50%',
          objectFit: 'cover',
        }}
      />
    </motion.div>
  );
};
