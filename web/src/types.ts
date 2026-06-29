export interface Option {
  value: string; // slug or code
  label: string;
  categorySlug?: string; // for professions, to filter by selected category
}

export interface Taxonomy {
  categories: Option[];
  professions: Option[];
  services: Option[];
  languages: Option[];
}

/** Mirrors the writable columns of public.onboarding_submissions. */
export interface OnboardingForm {
  full_name: string;
  email: string;
  phone: string;
  display_name: string;
  studio_name: string;
  entity_type: string;
  primary_category_slug: string;
  primary_profession_slug: string;
  years_experience: string;
  headline: string;
  bio: string;
  city: string;
  country_code: string;
  travel_willing: boolean;
  languages: string[];
  services: string[];
  website_url: string;
  instagram_url: string;
  rate_min: string;
  rate_max: string;
  rate_currency: string;
  rate_unit: string;
  consent: boolean;
}

export const emptyForm: OnboardingForm = {
  full_name: '',
  email: '',
  phone: '',
  display_name: '',
  studio_name: '',
  entity_type: 'individual',
  primary_category_slug: '',
  primary_profession_slug: '',
  years_experience: '',
  headline: '',
  bio: '',
  city: '',
  country_code: '',
  travel_willing: false,
  languages: [],
  services: [],
  website_url: '',
  instagram_url: '',
  rate_min: '',
  rate_max: '',
  rate_currency: 'INR',
  rate_unit: 'project',
  consent: false,
};
