export type SkillGroup = {
  experience: string;
  skills: string[];
};

export type SkillTranslation = {
  id: string;
  rawExperience: string;
  groups: SkillGroup[];
  resumeSentence: string;
  createdAt: string;
};
