'use client';

import React, { useReducer, useRef } from 'react';
import { supabase } from '@/lib/supabase/client';
import { useRouter } from 'next/navigation';

type LoginState = {
  step: 'floor' | 'apartment' | 'pin';
  floor: number | null;
  apartment: number | null;
  pin: string;
  error: string | null;
};

type LoginAction =
  | { type: 'SET_FLOOR'; payload: number }
  | { type: 'SET_APARTMENT'; payload: number }
  | { type: 'APPEND_PIN'; payload: string }
  | { type: 'REMOVE_PIN' }
  | { type: 'SET_ERROR'; payload: string }
  | { type: 'RESET' };

const initialState: LoginState = {
  step: 'floor',
  floor: null,
  apartment: null,
  pin: '',
  error: null,
};

function loginReducer(state: LoginState, action: LoginAction): LoginState {
  switch (action.type) {
    case 'SET_FLOOR':
      return { ...state, floor: action.payload, step: 'apartment', error: null };
    case 'SET_APARTMENT':
      return { ...state, apartment: action.payload, step: 'pin', error: null };
    case 'APPEND_PIN':
      if (state.pin.length < 4) {
        return { ...state, pin: state.pin + action.payload, error: null };
      }
      return state;
    case 'REMOVE_PIN':
      return { ...state, pin: state.pin.slice(0, -1), error: null };
    case 'SET_ERROR':
      return { ...state, error: action.payload, pin: '' };
    case 'RESET':
      return initialState;
    default:
      return state;
  }
}

export default function TopographicalLogin() {
  const [state, dispatch] = useReducer(loginReducer, initialState);
  const isSubmitting = useRef(false);
  const router = useRouter();

  const handleFloorSelect = (floor: number) => {
    dispatch({ type: 'SET_FLOOR', payload: floor });
  };

  const handleApartmentSelect = (apartment: number) => {
    dispatch({ type: 'SET_APARTMENT', payload: apartment });
  };

  const handlePinClick = async (digit: string) => {
    if (state.pin.length >= 4 || isSubmitting.current) return;

    const newPinLength = state.pin.length + 1;
    dispatch({ type: 'APPEND_PIN', payload: digit });

    if (newPinLength === 4) {
      if (isSubmitting.current) return;
      isSubmitting.current = true;

      const derivedEmail = `apt_E${state.floor}A${state.apartment}@amandier-b.internal`;
      const currentPin = state.pin + digit;

      const { error } = await supabase.auth.signInWithPassword({
        email: derivedEmail,
        password: currentPin, // Using PIN as password for Supabase Auth
      });

      if (error) {
        dispatch({ type: 'SET_ERROR', payload: 'Code PIN incorrect' });
        isSubmitting.current = false;
      } else {
        // Success
        router.push('/resident/dashboard');
      }
    }
  };

  const handleBackspace = () => {
    dispatch({ type: 'REMOVE_PIN' });
  };

  const handleReset = () => {
    dispatch({ type: 'RESET' });
  };

  const renderFloorSelector = () => (
    <div className="grid grid-cols-1 gap-4">
      <h2 className="mb-4 text-center text-xl font-bold">Sélectionnez votre étage</h2>
      {[5, 4, 3, 2, 1].map((f) => (
        <button
          key={f}
          onClick={() => handleFloorSelect(f)}
          className="rounded-lg bg-blue-600 p-4 text-lg font-semibold text-white shadow-sm hover:bg-blue-700"
        >
          Étage {f}
        </button>
      ))}
    </div>
  );

  const renderApartmentSelector = () => (
    <div className="grid grid-cols-1 gap-4">
      <h2 className="mb-4 text-center text-xl font-bold">Étage {state.floor} - Quel appartement ?</h2>
      {[1, 2, 3].map((a) => (
        <button
          key={a}
          onClick={() => handleApartmentSelect(a)}
          className="rounded-lg bg-green-600 p-4 text-lg font-semibold text-white shadow-sm hover:bg-green-700"
        >
          Appartement {a}
        </button>
      ))}
      <button onClick={handleReset} className="mt-4 p-2 text-gray-500 underline">Retour</button>
    </div>
  );

  const renderPinPad = () => {
    // Generate an array of 4 dots, filled based on PIN length
    const dots = Array.from({ length: 4 }).map((_, i) => (
      <div
        key={i}
        className={`mx-2 h-4 w-4 rounded-full ${
          i < state.pin.length ? 'bg-gray-800' : 'bg-gray-300'
        }`}
      />
    ));

    // Check if we are currently submitting to disable buttons
    // Since we don't want to access ref during render directly to affect DOM structurally
    // We will just read it once or use a safe mechanism. However, for a ref, it's safer
    // to track submission via state if it needs to disable UI. Let's just disable visually
    // when pin is 4 length instead, since that implies submitting.
    const isFull = state.pin.length === 4;

    return (
      <div className="flex flex-col items-center">
        <h2 className="mb-2 text-center text-xl font-bold">Code PIN</h2>
        <p className="mb-6 text-sm text-gray-500">
          Appartement E{state.floor}A{state.apartment}
        </p>

        {state.error && <p className="mb-4 text-red-500">{state.error}</p>}

        <div className="mb-8 flex justify-center">
          {dots}
          <input
            type="password"
            value={state.pin}
            readOnly
            className="hidden"
            aria-hidden="true"
            autoComplete="off"
          />
        </div>

        <div className="grid grid-cols-3 gap-4">
          {[1, 2, 3, 4, 5, 6, 7, 8, 9].map((digit) => (
            <button
              key={digit}
              onClick={() => handlePinClick(digit.toString())}
              disabled={isFull}
              className="flex h-16 w-16 items-center justify-center rounded-full bg-gray-200 text-2xl font-semibold shadow hover:bg-gray-300 disabled:opacity-50"
            >
              {digit}
            </button>
          ))}
          <button onClick={handleReset} className="flex h-16 w-16 items-center justify-center rounded-full text-sm text-gray-600 hover:bg-gray-100">
            Annuler
          </button>
          <button
            onClick={() => handlePinClick('0')}
            disabled={isFull}
            className="flex h-16 w-16 items-center justify-center rounded-full bg-gray-200 text-2xl font-semibold shadow hover:bg-gray-300 disabled:opacity-50"
          >
            0
          </button>
          <button onClick={handleBackspace} disabled={isFull} className="flex h-16 w-16 items-center justify-center rounded-full text-gray-600 hover:bg-gray-100 disabled:opacity-50">
            ⌫
          </button>
        </div>
      </div>
    );
  };

  return (
    <div className="flex min-h-screen items-center justify-center bg-gray-50 p-4">
      <div className="w-full max-w-sm rounded-xl bg-white p-6 shadow-lg">
        {state.step === 'floor' && renderFloorSelector()}
        {state.step === 'apartment' && renderApartmentSelector()}
        {state.step === 'pin' && renderPinPad()}
      </div>
    </div>
  );
}
