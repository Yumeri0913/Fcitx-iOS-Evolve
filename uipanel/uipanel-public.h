#pragma once

#include <string>

bool inputContextIsFocused(const char *inputContext);
std::string getCandidateActions(const char *inputContext, int index);
void activateCandidateAction(const char *inputContext, int index, int id);
void activateCandidateTabAction(const char *inputContext, int id);
void selectCandidate(const char *inputContext, int index);
// Google Pinyin key symbols: commit the first candidate of the composition,
// then the text as is (no punctuation conversion), in this order.
void commitFirstCandidateAndText(const char *inputContext, const char *text);
void activateStatusAreaAction(const char *inputContext, int id);
void scroll(const char *inputContext, int start, int count);
void page(const char *inputContext, bool next);
